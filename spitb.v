`timescale 1ns / 1ps
module spitb;
    reg clk, rst, start;
    reg [1:0] mode;
    reg [7:0] master_tx, slave_tx;
    wire [7:0] master_rx, slave_rx;
    wire sclk, ss, mosi, miso;
    wire finish;
    wire slave_rxvalid;
    
    spim uut_master(
        .clk(clk),
        .rst(rst),
        .start(start),
        .mode(mode),
        .txdata(master_tx),
        .rxdata(master_rx),
        .sclk(sclk),
        .ss(ss),
        .mosi(mosi),
        .miso(miso),
        .finish(finish)
    );
    
    spis uut_slave(
        .Sclk(sclk),
        .SS(ss),
        .MOSI(mosi),
        .MISO(miso),
        .MODE(mode),
        .rst(rst),
        .TxData(slave_tx),
        .RxData(slave_rx),
        .RxValid(slave_rxvalid)
    );
    
    initial clk = 0;
    always #5 clk = ~clk;
    
    initial begin
        rst = 1;
        start = 0;
        mode = 2'b10; // SPI Mode 0
        master_tx = 8'hA5;
        slave_tx  = 8'h3C;
        #20;
        rst = 0;
        #20;
        
        $display("SPI Transfer Starts");
        start = 1;
        #10;
        start = 0;
        
        // Run long enough for full transmission
        #5000;
        
        $display("Master Tx : %h", master_tx);
        $display("Master Rx : %h", master_rx);
        $display("Slave Tx  : %h", slave_tx);
        $display("Slave Rx  : %h", slave_rx);
        
        if (master_tx == slave_rx && master_rx == slave_tx)
            $display("SPI Transfer Successful");
        else
            $display("Data Mismatch");
            
        #50;
        $stop;
    end
endmodule