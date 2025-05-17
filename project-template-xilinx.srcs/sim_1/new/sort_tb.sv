`timescale 1ns/1ps

module sort_tb;
    // 时钟和复位信号
    reg clk;
    reg rst;
    reg start;

    // 输入和输出信号
    reg [11:0] data_in [0:31]; // 输入数据
    wire [4:0] index [0:31];   // 输出排序后的序号
    wire done;                 // 排序完成信号

    // 实例化排序模块
    sort uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .data_in(data_in),
        .index(index),
        .done(done)
    );

    // 100MHz 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 时钟周期为 10ns (100MHz)
    end

    // 测试输入数据初始化
    initial begin
        // 初始化信号
        rst = 1;
        start = 0;
        #20; // 保持复位状态 20ns

        // 释放复位信号
        rst = 0;

        // 设置输入数据
        data_in[0] = 12'd9;
        data_in[1] = 12'd18;
        data_in[2] = 12'd7;
        data_in[3] = 12'd7;
        data_in[4] = 12'd15;
        data_in[5] = 12'd3;
        data_in[6] = 12'd20;
        data_in[7] = 12'd12;
        data_in[8] = 12'd2;
        data_in[9] = 12'd25;
        data_in[10] = 12'd1;
        data_in[11] = 12'd30;
        data_in[12] = 12'd14;
        data_in[13] = 12'd23;
        data_in[14] = 12'd8;
        data_in[15] = 12'd6;
        data_in[16] = 12'd19;
        data_in[17] = 12'd4;
        data_in[18] = 12'd13;
        data_in[19] = 12'd29;
        data_in[20] = 12'd10;
        data_in[21] = 12'd26;
        data_in[22] = 12'd11;
        data_in[23] = 12'd21;
        data_in[24] = 12'd16;
        data_in[25] = 12'd5;
        data_in[26] = 12'd28;
        data_in[27] = 12'd24;
        data_in[28] = 12'd22;
        data_in[29] = 12'd27;
        data_in[30] = 12'd17;
        data_in[31] = 12'd31;

        // 启动排序
        #10;
        start = 1;
        #10;
        start = 0;

        // 等待排序完成
        wait(done);

        // 验证结果
        #10;
        $display("排序完成，输出结果：");
        for (integer i = 0; i < 32; i = i + 1) begin
            $display("index[%0d] = %0d", 31 - i, index[31 - i]);
        end

        // 结束仿真
        $stop;
    end
endmodule