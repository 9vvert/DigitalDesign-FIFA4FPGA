`timescale 1ns/1ps

module ram_tb;

    // Parameters
    localparam ADDR_WIDTH = 4;
    localparam DATA_WIDTH = 64;
    localparam READ_WIDTH = 16;

    // Signals
    reg clk = 0;
    reg rst = 0;
    reg [13:0] wr_addr = 0;
    reg [DATA_WIDTH-1:0] wr_data = 64'h1122334455667788;
    reg wr_en = 0;

    reg [15:0] rd_addr = 0;
    reg rd_en = 0;
    wire [READ_WIDTH-1:0] rd_data;

    // Clock generation
    always #5 clk = ~clk;

    reg [3:0] counter;
    // Instantiate blk_mem_gen_1
    // NOTE: Replace this with your actual memory instantiation if needed.
    // blk_mem_gen_1 mem_inst (
    //     .clka(clk),
    //     .ena(1'b1),
    //     .wea(wr_en),
    //     .addra(wr_addr),
    //     .dina(wr_data),
    //     .clkb(clk),
    //     .enb(rd_en),
    //     .addrb(rd_addr),
    //     .doutb(rd_data)
    // );
    reg fill_batch;
    reg [63:0] write_data;
    reg [13:0] write_addr;
    reg write_enable;
    video u_video800x600at72 (
        .clk(clk),
        .ui_clk(clk),
        .fill_batch(fill_batch),  //拉高这个信号表示需要填充40KB的缓存数据
        .write_data(write_data) ,    //显存通过这三个信号来写入数据
        .write_addr(write_addr),
        .write_enable(write_enable)
    );

    reg start;
    reg [11:0]data_in[31:0];
    reg [4:0] index[31:0];
    reg done;

    sort u_sort(
        .clk(clk),
        .rst(rst),
        .start(start),
        .data_in(data_in),
        .index(index),
        .done(done)
    );
    initial begin
        $display("Start simulation");
        rst = 1;
        data_in[0] = 23;
        data_in[1] = 12;
        data_in[2] = 45;
        data_in[3] = 67;
        data_in[4] = 89;
        data_in[5] = 34;
        data_in[6] = 56;
        data_in[7] = 78;
        data_in[8] = 90;
        data_in[9] = 11;
        data_in[10] = 22;
        data_in[11] = 33;
        data_in[12] = 44;
        data_in[13] = 55;
        data_in[14] = 66;
        data_in[15] = 11;
        data_in[16] = 88;
        data_in[17] = 99;
        data_in[18] = 10;
        data_in[19] = 20;
        data_in[20] = 34;
        data_in[21] = 40;
        data_in[22] = 34;
        data_in[23] = 0;
        data_in[24] = 0;
        data_in[25] = 0;
        data_in[26] = 0;
        data_in[27] = 0;
        data_in[28] = 0;
        data_in[29] = 0;
        data_in[30] = 0;
        data_in[31] = 0;

        #10;
        rst = 0;
        start = 1;
        #10;
        start = 0;
        // Write 64-bit data to address 0
        
        write_data = 64'h1122334455667788;
        write_addr = 0;
        write_enable = 1;
         // Example data
        #10;
        write_enable = 0;

        // Read back 16 bits at a time from the same address
        // Assuming the memory supports 16-bit read width at the same address
        // and outputs the corresponding 16 bits per access.
        // You may need to adjust addressing depending on your memory configuration.

        // Read 1st 16 bits (lowest address)
        #100000;
    end

    
    
endmodule