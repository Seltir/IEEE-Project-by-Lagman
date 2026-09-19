
// =================================================================
// VGA HSYNC / VSYNC GENERATOR
// =================================================================
//
// 640x480 VGA @ ~60 Hz
//
// Pixel clock expected: approximately 25 MHz.
//
// Horizontal:
//   visible = 640
//   front   = 16
//   sync    = 96
//   back    = 48
//   total   = 800
//
// Vertical:
//   visible = 480
//   front   = 10
//   sync    = 2
//   back    = 33
//   total   = 525
//
// =================================================================

module hvsync_generator (
    input  wire clk,
    input  wire reset_n,

    output reg hsync,
    output reg vsync,
    output wire display_on,

    output wire [9:0] hpos,
    output wire [9:0] vpos
);

    reg [9:0] h_count;
    reg [9:0] v_count;

    // ------------------------------------------------------------
    // Horizontal counter
    // ------------------------------------------------------------

    always @(posedge clk) begin

        if (!reset_n) begin

            h_count <= 10'd0;

        end

        else begin

            if (h_count == 10'd799)
                h_count <= 10'd0;
            else
                h_count <= h_count + 1'b1;

        end

    end

    // ------------------------------------------------------------
    // Vertical counter
    // ------------------------------------------------------------

    always @(posedge clk) begin

        if (!reset_n) begin

            v_count <= 10'd0;

        end

        else begin

            if (h_count == 10'd799) begin

                if (v_count == 10'd524)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 1'b1;

            end

        end

    end

    assign hpos = h_count;
    assign vpos = v_count;

    // ------------------------------------------------------------
    // Display area
    // ------------------------------------------------------------

    assign display_on =
        (h_count < 10'd640) &&
        (v_count < 10'd480);

    // ------------------------------------------------------------
    // Horizontal sync
    // Negative polarity
    // ------------------------------------------------------------

    always @(*) begin

        if ((h_count >= 10'd656) &&
            (h_count < 10'd752))

            hsync = 1'b0;

        else

            hsync = 1'b1;

    end

    // ------------------------------------------------------------
    // Vertical sync
    // Negative polarity
    // ------------------------------------------------------------

    always @(*) begin

        if ((v_count >= 10'd490) &&
            (v_count < 10'd492))

            vsync = 1'b0;

        else

            vsync = 1'b1;

    end

endmodule

`default_nettype wire