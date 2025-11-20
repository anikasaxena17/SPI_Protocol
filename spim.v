`timescale 1ns / 1ps
module spim(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [1:0] mode,
    input wire [7:0] txdata,
    output reg [7:0] rxdata,
    output reg sclk,
    output reg ss,
    output reg mosi,
    input wire miso,
    output reg finish
    );
    
    wire cpol = (mode == 2 || mode == 3);
    wire cpha = (mode == 1 || mode == 3);
    
    // Mode decoding
    wire sample_on_pos = (mode == 2'b00 || mode == 2'b11);
    wire shift_on_pos  = (mode == 2'b01 || mode == 2'b10);
    
    localparam st_idle  = 2'd0;
    localparam st_load  = 2'd1;
    localparam st_shift = 2'd2;
    localparam st_done  = 2'd3;
    
    reg [1:0] state, nextstate;
    reg [3:0] div_cnt;
    reg prev_sclk;
    
    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [3:0] bit_cnt;
    reg start_d, start_edge;
    
    // Detect start pulse
    always @(posedge clk) begin
        if (rst) begin
            start_d <= 1'b0;
            start_edge <= 1'b0;
        end else begin
            start_d <= start;
            start_edge <= ~start_d & start;
        end
    end
    
    // Generate SCLK (fast divider for simulation)
    always @(posedge clk) begin
        if (rst) begin
            div_cnt <= 0;
            sclk <= cpol;
        end else begin
            if (state == st_shift) begin
                if (div_cnt == 1) begin // Faster SCLK
                    div_cnt <= 0;
                    sclk <= ~sclk;
                end else begin
                    div_cnt <= div_cnt + 1;
                end
            end else begin
                div_cnt <= 0;
                sclk <= cpol;
            end
        end
    end
    
    always @(posedge clk) begin
        if (rst)
            prev_sclk <= cpol;
        else
            prev_sclk <= sclk;
    end
    
    wire sclk_posedge = (~prev_sclk & sclk);
    wire sclk_negedge = (prev_sclk & ~sclk);
    
    // FSM next state
    always @(*) begin
        nextstate = state;
        case(state)
            st_idle:  if (start_edge) nextstate = st_load;
            st_load:  nextstate = st_shift;
            st_shift: if (bit_cnt == 4'd8 && 
                          ((sample_on_pos && sclk_posedge) || 
                           (!sample_on_pos && sclk_negedge))) 
                          nextstate = st_done;
            st_done:  nextstate = st_idle;
        endcase
    end
    
    // FSM behavior
    always @(posedge clk) begin
        if (rst) begin
            state <= st_idle;
            ss <= 1'b1;
            mosi <= 1'b0;
            bit_cnt <= 0;
            rxdata <= 0;
            tx_shift <= 0;
            rx_shift <= 0;
            finish <= 0;
        end else begin
            state <= nextstate;
            finish <= 0;
            
            case(nextstate)
                st_idle: begin
                    ss <= 1'b1;
                    bit_cnt <= 0;
                end
                
                st_load: begin
                    ss <= 1'b0;
                    tx_shift <= txdata;
                    rx_shift <= 0;
                    bit_cnt <= 0;
                    mosi <= txdata[7];
                end
                
                st_shift: begin
                    // sample
                   // Handle sampling and shifting for all SPI modes
                    if (mode == 2'b00) begin
                        if (sclk_posedge) begin
                            rx_shift <= {rx_shift[6:0], miso};
                            bit_cnt <= bit_cnt + 1;
                        end
                        if (sclk_negedge) begin
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            mosi <= tx_shift[6];
                        end
                    end 
                    else if (mode == 2'b01) begin
                        if (sclk_negedge) begin
                            rx_shift <= {rx_shift[6:0], miso};
                            bit_cnt <= bit_cnt + 1;
                        end
                        if (sclk_posedge) begin
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            mosi <= tx_shift[6];
                        end
                    end 
                    else if (mode == 2'b10) begin
                        if (sclk_negedge) begin
                            rx_shift <= {rx_shift[6:0], miso};
                            bit_cnt <= bit_cnt + 1;
                        end
                        if (sclk_posedge) begin
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            mosi <= tx_shift[6];
                        end
                    end 
                    else if (mode == 2'b11) begin
                        if (sclk_posedge) begin
                            rx_shift <= {rx_shift[6:0], miso};
                            bit_cnt <= bit_cnt + 1;
                        end
                        if (sclk_negedge) begin
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            mosi <= tx_shift[7];
                        end
                    end
                end
                
                st_done: begin
                    ss <= 1'b1;
                    rxdata <= rx_shift;
                    finish <= 1'b1;
                end
            endcase
        end
    end
endmodule