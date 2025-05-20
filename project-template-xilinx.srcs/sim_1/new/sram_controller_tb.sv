`timescale 1ns / 1ps

module sram_controller_tb;

    reg         clk;
    reg         rst_n;

    // 上层接口信号
    reg         req;
    reg         wr;
    reg [19:0]  addr;
    reg [31:0]  din;
    reg [3:0]   be_n;
    wire [31:0] dout;
    wire        ack;

    // SRAM接口信号
    wire [31:0] base_ram_data;
    wire [19:0] base_ram_addr;
    wire [3:0]  base_ram_be_n;
    wire        base_ram_ce_n;
    wire        base_ram_oe_n;
    wire        base_ram_we_n;

    // SRAM仿真存储单元
    reg [31:0] sram_mem [0:2**20-1]; // 4MB/4B = 2^20 words
    reg [31:0] sram_data_out;
    reg        sram_data_oe;

    // 模拟SRAM的inout行为
    assign base_ram_data = sram_data_oe ? sram_data_out : 32'bz;

    // 读：SRAM读使能和片选有效时输出数据
    always @(*) begin
        if (!base_ram_ce_n && !base_ram_oe_n && base_ram_we_n) begin
            sram_data_oe  = 1'b1;
            sram_data_out = sram_mem[base_ram_addr];
        end else begin
            sram_data_oe  = 1'b0;
            sram_data_out = 32'b0;
        end
    end

    // 写：SRAM写使能和片选有效时写入数据
    always @(negedge base_ram_we_n) begin
        if (!base_ram_ce_n) begin
            // 字节写
            if (!base_ram_be_n[0]) sram_mem[base_ram_addr][ 7: 0] <= base_ram_data[ 7: 0];
            if (!base_ram_be_n[1]) sram_mem[base_ram_addr][15: 8] <= base_ram_data[15: 8];
            if (!base_ram_be_n[2]) sram_mem[base_ram_addr][23:16] <= base_ram_data[23:16];
            if (!base_ram_be_n[3]) sram_mem[base_ram_addr][31:24] <= base_ram_data[31:24];
        end
    end

    // 实例化控制器
    sram_IO uut (
        .clk             (clk),
        .rst_n           (rst_n),
        .req             (req),
        .wr              (wr),
        .addr            (addr),
        .din             (din),
        .be_n            (be_n),
        .dout            (dout),
        .ack             (ack),
        .base_ram_data   (base_ram_data),
        .base_ram_addr   (base_ram_addr),
        .base_ram_be_n   (base_ram_be_n),
        .base_ram_ce_n   (base_ram_ce_n),
        .base_ram_oe_n   (base_ram_oe_n),
        .base_ram_we_n   (base_ram_we_n)
    );

    // 时钟生成
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        req = 0;
        wr = 0;
        addr = 0;
        din = 0;
        be_n = 4'b0000;
        #20;
        rst_n = 1;
        #20;

        // 写测试
        @(negedge clk);
        addr = 20'h12345;
        din  = 32'hA5A5_5A5A;
        be_n = 4'b0000;
        wr   = 1;
        req  = 1;
        @(negedge clk);
        req = 0;
        wait(ack);
        @(negedge clk);

        // 读测试
        addr = 20'h12345;
        wr   = 0;
        req  = 1;
        @(negedge clk);
        req = 0;
        wait(ack);
        @(negedge clk);

        if (dout == 32'hA5A5_5A5A)
            $display("SRAM READ/WRITE PASS: %h", dout);
        else
            $display("SRAM READ/WRITE FAIL! dout=%h", dout);

        // 字节写测试
        addr = 20'h12346;
        din  = 32'hDEADBEEF;
        be_n = 4'b1110; // 只写最低字节
        wr   = 1;
        req  = 1;
        @(negedge clk);
        req = 0;
        wait(ack);
        @(negedge clk);

        // 读回新地址
        addr = 20'h12346;
        wr   = 0;
        req  = 1;
        @(negedge clk);
        req = 0;
        wait(ack);
        @(negedge clk);

        if (dout[7:0] == 8'hEF)
            $display("SRAM BYTE WRITE PASS: %h", dout);
        else
            $display("SRAM BYTE WRITE FAIL! dout=%h", dout);

        $stop;
    end

endmodule