`timescale 1ns / 1ps
module spis (
    input  wire       Sclk,
    input  wire       SS,
    input  wire       MOSI,
    output reg        MISO,
    input  wire [1:0] MODE,
    input  wire       rst,
    input  wire [7:0] TxData,
    output reg [7:0]  RxData,
    output reg        RxValid
);

    wire CPOL = (MODE == 2) || (MODE == 3);
    wire CPHA = (MODE == 1) || (MODE == 3);

    reg [7:0] rx_shift, tx_shift;
    reg [3:0] bit_cnt;

    // Counter: reset bit_cnt when SS is high as well
    always @(posedge Sclk or posedge rst) begin
        if (rst)
            bit_cnt <= 0;
        else if (SS)
            bit_cnt <= 0;
        else begin
            if (bit_cnt == 4'd8)
                bit_cnt <= 0;
            else
                bit_cnt <= bit_cnt + 1;
        end
    end

    // Edge detect (we only use pos/neg edge booleans inside the combinational case)
    reg prev_sclk;
    always @(posedge Sclk or negedge Sclk or posedge rst) begin
        if (rst)
            prev_sclk <= CPOL;
        else
            prev_sclk <= Sclk;
    end

    wire pos_edge = (~prev_sclk & Sclk);
    wire neg_edge = (prev_sclk & ~Sclk);

    // Shift logic: handle sample/drive on SCLK edges
    always @(posedge Sclk or negedge Sclk or posedge rst) begin
        if (rst) begin
            tx_shift <= 0;
            rx_shift <= 0;
            MISO     <= 1'b0;
        end else if (SS) begin
            // when slave deselected, ensure MISO is idle
            MISO <= 1'b0;
        end else begin
            case ({CPOL, CPHA})
                // Mode 0 & 3: drive on negedge, sample on posedge
                2'b00: begin
                    if (neg_edge) begin
                        // drive MISO first, then shift for next bit
                        MISO <= tx_shift[6];
                        tx_shift <= {tx_shift[6:0], 1'b0};
                    end
                    if (pos_edge) begin
                        rx_shift <= {rx_shift[6:0], MOSI};
                    end
                end
                // Mode 1 & 2: drive on posedge, sample on negedge
                2'b01: begin
                    if (pos_edge) begin
                        MISO <= tx_shift[6];
                        tx_shift <= {tx_shift[6:0], 1'b0};
                    end
                    if (neg_edge) begin
                        rx_shift <= {rx_shift[6:0], MOSI};
                    end
                end
                2'b10: begin
                    if (pos_edge) begin
                        MISO <= tx_shift[6];
                        tx_shift <= {tx_shift[6:0], 1'b0};
                    end
                    if (neg_edge) begin
                        rx_shift <= {rx_shift[6:0], MOSI};
                    end
                end
                2'b11: begin
                    if (neg_edge) begin
                        // drive MISO first, then shift for next bit
                        MISO <= tx_shift[7];
                        tx_shift <= {tx_shift[6:0], 1'b0};
                    end
                    if (pos_edge) begin
                        rx_shift <= {rx_shift[6:0], MOSI};
                    end
                end
            endcase
        end
    end

    // Latch RxData when 8 bits received (on Sclk posedge here; ok for Mode0)
    always @(posedge Sclk or posedge rst) begin
        if (rst) begin
            RxData <= 0;
            RxValid <= 0;
        end else if (!SS && bit_cnt == 4'd8) begin
            RxData <= rx_shift;
            RxValid <= 1'b1;
        end else begin
            RxValid <= 0;
        end
    end

    // Load TxData and drive first MISO bit immediately when SS goes low
    always @(negedge SS or posedge rst) begin
        if (rst) begin
            tx_shift <= 0;
            MISO <= 1'b0;
            rx_shift <= 0;
        end else begin
            tx_shift <= TxData;
            rx_shift <= 0;
            // drive MSB immediately so master can sample it at first rising edge
            MISO <= TxData[7];
        end
    end

endmodule