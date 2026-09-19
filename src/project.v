`default_nettype none

module tt_um_vga_slot_machine (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire ena,
    input  wire clk,
    input  wire rst_n
);

    // ============================================================
    // VGA SIGNALS
    // ============================================================
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire hsync;
    wire vsync;
    wire display_on;

    hvsync_generator vga (
        .clk(clk),
        .reset_n(rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(display_on),
        .hpos(pixel_x),
        .vpos(pixel_y)
    );

    // ============================================================
    // OUTPUTS (Direct 2-bit per channel)
    // ============================================================
    reg [1:0] vga_r;
    reg [1:0] vga_g;
    reg [1:0] vga_b;

    assign uo_out = { hsync, vga_r, vsync, vga_g, vga_b };
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // ============================================================
    // SLOT MACHINE LOGIC
    // ============================================================
    localparam IDLE   = 3'd0;
    localparam SPIN1  = 3'd1;
    localparam SPIN2  = 3'd2;
    localparam SPIN3  = 3'd3;
    localparam RESULT = 3'd4;

    reg [2:0] state;
    reg [2:0] reel1, reel2, reel3;
    reg [15:0] random_counter;
    reg [4:0] spin_timer;
    reg lever_down, start_last;

    wire start_button = ui_in[5];
    wire start_pressed = start_button & ~start_last;

    // Small hardware mod-7 using lightweight lookups
    wire [2:0] rnd1 = (random_counter[2:0] >= 3'd7) ? (random_counter[2:0] - 3'd7) : random_counter[2:0];
    wire [2:0] rnd2 = (random_counter[5:3] >= 3'd7) ? (random_counter[5:3] - 3'd7) : random_counter[5:3];
    wire [2:0] rnd3 = (random_counter[8:6] >= 3'd7) ? (random_counter[8:6] - 3'd7) : random_counter[8:6];

    always @(posedge clk) begin
        if (!rst_n || random_counter == 16'h0000) begin
            random_counter <= 16'hACE1;
        end else begin
            random_counter <= {
                random_counter[14:0],
                random_counter[15] ^ random_counter[13] ^ random_counter[12] ^ random_counter[10]
            };
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= IDLE;
            reel1       <= 3'd0;
            reel2       <= 3'd1;
            reel3       <= 3'd2;
            spin_timer  <= 5'd0;
            lever_down  <= 1'b0;
            start_last  <= 1'b0;
        end else begin
            start_last <= start_button;

            case (state)
                IDLE: begin
                    lever_down <= 1'b0;
                    if (start_pressed) begin
                        lever_down <= 1'b1;
                        spin_timer <= 5'd0;
                        state      <= SPIN1;
                    end
                end

                SPIN1: begin
                    lever_down <= 1'b1;
                    if (spin_timer == 5'd25) begin
                        spin_timer <= 5'd0;
                        state      <= SPIN2;
                    end else begin
                        spin_timer <= spin_timer + 1'b1;
                        reel1 <= (reel1 == 3'd6) ? 3'd0 : reel1 + 1'b1;
                    end
                end

                SPIN2: begin
                    lever_down <= 1'b1;
                    if (spin_timer == 5'd25) begin
                        spin_timer <= 5'd0;
                        state      <= SPIN3;
                    end else begin
                        spin_timer <= spin_timer + 1'b1;
                        reel2 <= (reel2 == 3'd6) ? 3'd0 : reel2 + 1'b1;
                    end
                end

                SPIN3: begin
                    lever_down <= 1'b0;
                    if (spin_timer == 5'd25) begin
                        spin_timer <= 5'd0;
                        reel1      <= rnd1;
                        reel2      <= rnd2;
                        reel3      <= rnd3;
                        state      <= RESULT;
                    end else begin
                        spin_timer <= spin_timer + 1'b1;
                        reel3 <= (reel3 == 3'd6) ? 3'd0 : reel3 + 1'b1;
                    end
                end

                RESULT: begin
                    lever_down <= 1'b0;
                    if (start_pressed) begin
                        lever_down <= 1'b1;
                        spin_timer <= 5'd0;
                        state      <= SPIN1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // ============================================================
    // LIGHTWEIGHT GRAPHICS (NO HARDWARE MULTIPLIERS)
    // ============================================================
    function automatic symbol_pixel;
        input [2:0] symbol;
        input [5:0] sx; // Reduced to 6-bit localized offsets
        input [5:0] sy;
        reg result;
        begin
            result = 1'b0;
            case (symbol)
                3'd0: begin // CHERRY
                    if ((sx > 15 && sx < 36 && sy > 34 && sy < 55) ||
                        (sx > 30 && sx < 51 && sy > 29 && sy < 50) ||
                        (sx > 27 && sx < 31 && sy > 12 && sy < 35) ||
                        (sx > 29 && sx < 43 && sy > 10 && sy < 14))
                        result = 1'b1;
                end

                3'd1: begin // LEMON (Box approximation)
                    if (sx > 13 && sx < 52 && sy > 15 && sy < 52)
                        result = 1'b1;
                end

                3'd2: begin // ORANGE (Approximated with bounding octagonal bounds to avoid dx*dx multiplier!)
                    if (sx > 18 && sx < 46 && sy > 21 && sy < 49 &&
                       (sx + sy > 45) && (sx + sy < 89))
                        result = 1'b1;
                end

                3'd3: begin // SEVEN
                    if ((sy >= 10 && sy < 18) || (sx >= 45 && sx < 54 && sy >= 10 && sy < 55))
                        result = 1'b1;
                end

                3'd4: begin // DIAMOND
                    if (((sx >= 32 - sy) && (sx <= 32 + sy) && sy < 32) ||
                        ((sx >= 32 - (63-sy)) && (sx <= 32 + (63-sy)) && sy >= 32))
                        result = 1 me_1;
                end

                3'd5: begin // BAR
                    if (sx > 7 && sx < 57 && sy > 25 && sy < 40)
                        result = 1'b1;
                end

                3'd6: begin // BELL
                    if ((sx > 16 && sx < 48 && sy > 18 && sy < 50) ||
                        (sx > 11 && sx < 53 && sy > 45 && sy < 53))
                        result = 1'b1;
                end

                default: result = 1'b0;
            endcase
            symbol_pixel = result;
        end
    endfunction

    // Direct 2-bit RGB logic
    always @(*) begin
        reg [1:0] r, g, b;

        // Default Background (Dark Blue/Purple)
        r = 2'b00; g = 2'b00; b = 2'b01;

        // Machine Body
        if (pixel_x >= 60 && pixel_x < 580 && pixel_y >= 60 && pixel_y < 440) begin
            r = 2'b01; g = 2'b00; b = 2'b01;
        end

        // Header / Title Banner
        if (pixel_x >= 90 && pixel_x < 550 && pixel_y >= 75 && pixel_y < 115) begin
            r = 2'b11; g = 2'b00; b = 2'b00;
        end

        // Reel Windows Shared Comparison
        if (pixel_y >= 140 && pixel_y < 300) begin
            if ((pixel_x >= 100 && pixel_x < 230) ||
                (pixel_x >= 250 && pixel_x < 380) ||
                (pixel_x >= 400 && pixel_x < 530)) begin
                r = 2'b11; g = 2'b11; b = 2'b10;
            end
        end

        // Reel Symbols
        if (pixel_y >= 185 && pixel_y < 249) begin
            if (pixel_x >= 130 && pixel_x < 194) begin
                if (symbol_pixel(reel1, pixel_x[5:0] - 6'd2, pixel_y[5:0] - 6'd57)) begin
                    r = 2'b11; g = 2'b00; b = 2'b00;
                end
            end else if (pixel_x >= 280 && pixel_x < 344) begin
                if (symbol_pixel(reel2, pixel_x[5:0] - 6'd24, pixel_y[5:0] - 6'd57)) begin
                    r = 2'b00; g = 2'b01; b = 2'b11;
                end
            end else if (pixel_x >= 430 && pixel_x < 494) begin
                if (symbol_pixel(reel3, pixel_x[5:0] - 6'd46, pixel_y[5:0] - 6'd57)) begin
                    r = 2'b11; g = 2'b10; b = 2'b00;
                end
            end
        end

        // Lever Housing & Shaft
        if (pixel_x >= 535 && pixel_x < 565 && pixel_y >= 150 && pixel_y < 340) begin
            r = 2'b01; g = 2'b01; b = 2'b01;
        end
        if (pixel_x >= 545 && pixel_x < 555) begin
            if ((!lever_down && pixel_y >= 150 && pixel_y < 250) ||
                ( lever_down && pixel_y >= 200 && pixel_y < 300)) begin
                r = 2'b11; g = 2'b11; b = 2'b11;
            end
        end

        // Lever Ball (Box bounding instead of expensive circle multipliers)
        if (pixel_x >= 538 && pixel_x < 562) begin
            if ((!lever_down && pixel_y >= 133 && pixel_y < 157) ||
                ( lever_down && pixel_y >= 288 && pixel_y < 312)) begin
                r = 2'b11; g = 2'b00; b = 2'b00;
            end
        end

        // Result Light
        if (state == RESULT && pixel_x >= 180 && pixel_x < 460 && pixel_y >= 330 && pixel_y < 370) begin
            if (reel1 == reel2 && reel2 == reel3) begin
                r = 2'b11; g = 2'b11; b = 2'b00; // Jackpot
            end else if ((reel1 == reel2) || (reel2 == reel3) || (reel1 == reel3)) begin
                r = 2'b00; g = 2'b11; b = 2'b01; // 2 Match
            end else begin
                r = 2'b10; g = 2'b00; b = 2'b00; // Loss
            end
        end

        // Outer Border
        if ((pixel_x >= 60 && pixel_x < 68) || (pixel_x >= 572 && pixel_x < 580) ||
            (pixel_y >= 60 && pixel_y < 68) || (pixel_y >= 432 && pixel_y < 440)) begin
            r = 2'b11; g = 2'b11; b = 2'b00;
        end

        // Output multiplexer logic
        if (!display_on) begin
            vga_r = 2'b00; vga_g = 2'b00; vga_b = 2'b00;
        end else begin
            vga_r = r; vga_g = g; vga_b = b;
        end
    end

endmodule
`default_nettype wire
