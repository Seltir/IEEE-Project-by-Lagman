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
    // OUTPUTS
    // ============================================================

    reg [1:0] vga_r;
    reg [1:0] vga_g;
    reg [1:0] vga_b;

    /*
     * VGA Playground / Tiny Tapeout style output:
     *
     * uo_out[7] = HSYNC
     * uo_out[6:5] = RED
     * uo_out[4] = VSYNC
     * uo_out[3:2] = GREEN
     * uo_out[1:0] = BLUE
     */

    assign uo_out = {
        hsync,
        vga_r,
        vsync,
        vga_g,
        vga_b
    };

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // ============================================================
    // SLOT MACHINE
    // ============================================================

    localparam IDLE   = 3'd0;
    localparam SPIN1  = 3'd1;
    localparam SPIN2  = 3'd2;
    localparam SPIN3  = 3'd3;
    localparam RESULT = 3'd4;

    reg [2:0] state;

    reg [2:0] reel1;
    reg [2:0] reel2;
    reg [2:0] reel3;

    reg [15:0] random_counter;

    reg [4:0] spin_timer;

    // Lever animation
    reg lever_down;

    // Detect button edge
    reg start_last;

    wire start_button;
    wire start_pressed;

    assign start_button = ui_in[5];
    assign start_pressed = start_button & ~start_last;

    // ============================================================
    // RANDOM NUMBER GENERATOR
    // ============================================================

    always @(posedge clk) begin
        if (!rst_n) begin
            random_counter <= 16'hACE1;
        end
        else begin
            random_counter <= {
                random_counter[14:0],
                random_counter[15] ^
                random_counter[13] ^
                random_counter[12] ^
                random_counter[10]
            };
        end
    end

    // ============================================================
    // GAME LOGIC
    // ============================================================

    always @(posedge clk) begin
        if (!rst_n) begin

            state       <= IDLE;

            reel1       <= 3'd0;
            reel2       <= 3'd1;
            reel3       <= 3'd2;

            spin_timer  <= 0;

            lever_down  <= 1'b0;
            start_last  <= 1'b0;
        end

        else begin

            start_last <= start_button;

            case (state)

                // ------------------------------------------------
                // WAITING FOR PLAYER
                // ------------------------------------------------

                IDLE: begin

                    lever_down <= 1'b0;

                    if (start_pressed) begin

                        // Pull lever down
                        lever_down <= 1'b1;

                        spin_timer <= 0;

                        // Start first reel
                        state <= SPIN1;

                    end
                end

                // ------------------------------------------------
                // REEL 1
                // ------------------------------------------------

                SPIN1: begin

                    lever_down <= 1'b1;

                    if (spin_timer == 5'd25) begin

                        spin_timer <= 0;

                        state <= SPIN2;

                    end

                    else begin

                        spin_timer <= spin_timer + 1'b1;

                        if (reel1 == 3'd6)
                            reel1 <= 0;
                        else
                            reel1 <= reel1 + 1'b1;

                    end
                end

                // ------------------------------------------------
                // REEL 2
                // ------------------------------------------------

                SPIN2: begin

                    lever_down <= 1'b1;

                    if (spin_timer == 5'd25) begin

                        spin_timer <= 0;

                        state <= SPIN3;

                    end

                    else begin

                        spin_timer <= spin_timer + 1'b1;

                        if (reel2 == 3'd6)
                            reel2 <= 0;
                        else
                            reel2 <= reel2 + 1'b1;

                    end
                end

                // ------------------------------------------------
                // REEL 3
                // ------------------------------------------------

                SPIN3: begin

                    lever_down <= 1'b0;

                    if (spin_timer == 5'd25) begin

                        spin_timer <= 0;

                        // Add randomness when final reel stops
                        reel1 <= random_counter[2:0] % 7;
                        reel2 <= random_counter[5:3] % 7;
                        reel3 <= random_counter[8:6] % 7;

                        state <= RESULT;

                    end

                    else begin

                        spin_timer <= spin_timer + 1'b1;

                        if (reel3 == 3'd6)
                            reel3 <= 0;
                        else
                            reel3 <= reel3 + 1'b1;

                    end
                end

                // ------------------------------------------------
                // RESULT
                // ------------------------------------------------

                RESULT: begin

                    lever_down <= 1'b0;

                    // Pull lever again to play again
                    if (start_pressed) begin

                        lever_down <= 1'b1;

                        spin_timer <= 0;

                        state <= SPIN1;

                    end

                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

    // ============================================================
    // GRAPHICS
    // ============================================================

    reg [7:0] r;
    reg [7:0] g;
    reg [7:0] b;

    integer dx;
    integer dy;

    // ------------------------------------------------------------
    // Symbol renderer
    // ------------------------------------------------------------

    function symbol_pixel;

        input [2:0] symbol;
        input [6:0] sx;
        input [6:0] sy;

        reg result;

        begin

            result = 1'b0;

            case (symbol)

                // ------------------------------------------------
                // CHERRY
                // ------------------------------------------------

                3'd0: begin

                    if ((sx > 15 && sx < 36 &&
                         sy > 34 && sy < 55) ||
                        (sx > 30 && sx < 51 &&
                         sy > 29 && sy < 50))
                        result = 1'b1;

                    // stems
                    if ((sx > 27 && sx < 31 &&
                         sy > 12 && sy < 35) ||
                        (sx > 29 && sx < 43 &&
                         sy > 10 && sy < 14))
                        result = 1'b1;

                end

                // ------------------------------------------------
                // LEMON
                // ------------------------------------------------

                3'd1: begin

                    if (sx > 13 && sx < 52 &&
                        sy > 15 && sy < 52)
                        result = 1'b1;

                end

                // ------------------------------------------------
                // ORANGE
                // ------------------------------------------------

                3'd2: begin

                    dx = sx - 32;
                    dy = sy - 35;

                    if ((dx * dx + dy * dy) < 400)
                        result = 1'b1;

                end

                // ------------------------------------------------
                // SEVEN
                // ------------------------------------------------

                3'd3: begin

                    if (sy >= 10 && sy < 18)
                        result = 1'b1;

                    if (sx >= 45 && sx < 54 &&
                        sy >= 10 && sy < 55)
                        result = 1'b1;

                end

                // ------------------------------------------------
                // DIAMOND
                // ------------------------------------------------

                3'd4: begin

                    if ((sx >= 32 - sy) &&
                        (sx <= 32 + sy) &&
                        sy < 32)
                        result = 1'b1;

                    if ((sx >= 32 - (63-sy)) &&
                        (sx <= 32 + (63-sy)) &&
                        sy >= 32)
                        result = 1'b1;

                end

                // ------------------------------------------------
                // BAR
                // ------------------------------------------------

                3'd5: begin

                    if (sx > 7 && sx < 57 &&
                        sy > 25 && sy < 40)
                        result = 1'b1;

                end

                // ------------------------------------------------
                // BELL
                // ------------------------------------------------

                3'd6: begin

                    if (sx > 16 && sx < 48 &&
                        sy > 18 && sy < 50)
                        result = 1'b1;

                    if (sx > 11 && sx < 53 &&
                        sy > 45 && sy < 53)
                        result = 1'b1;

                end

                default:
                    result = 1'b0;

            endcase

            symbol_pixel = result;

        end

    endfunction

    // ============================================================
    // VGA DRAWING
    // ============================================================

    always @(*) begin

        // --------------------------------------------------------
        // Background
        // --------------------------------------------------------

        r = 8'd8;
        g = 8'd8;
        b = 8'd15;

        // --------------------------------------------------------
        // Machine body
        // --------------------------------------------------------

        if (pixel_x >= 60 && pixel_x < 580 &&
            pixel_y >= 60 && pixel_y < 440) begin

            r = 8'd45;
            g = 8'd20;
            b = 8'd55;

        end

        // --------------------------------------------------------
        // Top title area
        // --------------------------------------------------------

        if (pixel_x >= 90 && pixel_x < 550 &&
            pixel_y >= 75 && pixel_y < 115) begin

            r = 8'd220;
            g = 8'd40;
            b = 8'd40;

        end

        // --------------------------------------------------------
        // REEL WINDOWS
        // --------------------------------------------------------

        if (pixel_x >= 100 && pixel_x < 230 &&
            pixel_y >= 140 && pixel_y < 300) begin

            r = 8'd240;
            g = 8'd230;
            b = 8'd180;

        end

        if (pixel_x >= 250 && pixel_x < 380 &&
            pixel_y >= 140 && pixel_y < 300) begin

            r = 8'd240;
            g = 8'd230;
            b = 8'd180;

        end

        if (pixel_x >= 400 && pixel_x < 530 &&
            pixel_y >= 140 && pixel_y < 300) begin

            r = 8'd240;
            g = 8'd230;
            b = 8'd180;

        end

        // --------------------------------------------------------
        // REEL 1 SYMBOL
        // --------------------------------------------------------

        if (pixel_x >= 130 && pixel_x < 194 &&
            pixel_y >= 185 && pixel_y < 249) begin

            if (symbol_pixel(
                    reel1,
                    pixel_x - 130,
                    pixel_y - 185)) begin

                r = 8'd230;
                g = 8'd30;
                b = 8'd30;

            end

        end

        // --------------------------------------------------------
        // REEL 2 SYMBOL
        // --------------------------------------------------------

        if (pixel_x >= 280 && pixel_x < 344 &&
            pixel_y >= 185 && pixel_y < 249) begin

            if (symbol_pixel(
                    reel2,
                    pixel_x - 280,
                    pixel_y - 185)) begin

                r = 8'd30;
                g = 8'd80;
                b = 8'd230;

            end

        end

        // --------------------------------------------------------
        // REEL 3 SYMBOL
        // --------------------------------------------------------

        if (pixel_x >= 430 && pixel_x < 494 &&
            pixel_y >= 185 && pixel_y < 249) begin

            if (symbol_pixel(
                    reel3,
                    pixel_x - 430,
                    pixel_y - 185)) begin

                r = 8'd240;
                g = 8'd170;
                b = 8'd20;

            end

        end

        // ========================================================
        // LEVER
        // ========================================================

        // Lever housing
        if (pixel_x >= 535 && pixel_x < 565 &&
            pixel_y >= 150 && pixel_y < 340) begin

            r = 8'd70;
            g = 8'd70;
            b = 8'd75;

        end

        // Lever shaft
        if (pixel_x >= 545 && pixel_x < 555) begin

            if (!lever_down &&
                pixel_y >= 150 && pixel_y < 250) begin

                r = 8'd190;
                g = 8'd190;
                b = 8'd190;

            end

            if (lever_down &&
                pixel_y >= 200 && pixel_y < 300) begin

                r = 8'd190;
                g = 8'd190;
                b = 8'd190;

            end

        end

        // Lever ball
        if (!lever_down) begin

            if ((pixel_x - 550) * (pixel_x - 550) +
                (pixel_y - 145) * (pixel_y - 145) < 225) begin

                r = 8'd220;
                g = 8'd30;
                b = 8'd30;

            end

        end

        else begin

            if ((pixel_x - 550) * (pixel_x - 550) +
                (pixel_y - 300) * (pixel_y - 300) < 225) begin

                r = 8'd220;
                g = 8'd30;
                b = 8'd30;

            end

        end

        // --------------------------------------------------------
        // RESULT LIGHT
        // --------------------------------------------------------

        if (state == RESULT) begin

            // JACKPOT
            if (reel1 == reel2 && reel2 == reel3) begin

                if (pixel_x >= 180 && pixel_x < 460 &&
                    pixel_y >= 330 && pixel_y < 370) begin

                    r = 8'd255;
                    g = 8'd210;
                    b = 8'd0;

                end

            end

            // TWO MATCH
            else if ((reel1 == reel2) ||
                     (reel2 == reel3) ||
                     (reel1 == reel3)) begin

                if (pixel_x >= 180 && pixel_x < 460 &&
                    pixel_y >= 330 && pixel_y < 370) begin

                    r = 8'd20;
                    g = 8'd220;
                    b = 8'd50;

                end

            end

            // LOSS
            else begin

                if (pixel_x >= 180 && pixel_x < 460 &&
                    pixel_y >= 330 && pixel_y < 370) begin

                    r = 8'd150;
                    g = 8'd20;
                    b = 8'd20;

                end

            end

        end

        // --------------------------------------------------------
        // Outer border
        // --------------------------------------------------------

        if ((pixel_x >= 60 && pixel_x < 68) ||
            (pixel_x >= 572 && pixel_x < 580) ||
            (pixel_y >= 60 && pixel_y < 68) ||
            (pixel_y >= 432 && pixel_y < 440)) begin

            r = 8'd255;
            g = 8'd190;
            b = 8'd0;

        end

        // --------------------------------------------------------
        // Convert to 2-bit VGA
        // --------------------------------------------------------

        if (!display_on) begin

            vga_r = 2'b00;
            vga_g = 2'b00;
            vga_b = 2'b00;

        end

        else begin

            vga_r = r[7:6];
            vga_g = g[7:6];
            vga_b = b[7:6];

        end

    end

endmodule

