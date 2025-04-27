`timescale 1ns / 1ps

module test_corr2angle;
    // 定义变量
    reg [11:0] x1, y1, x2, y2; // 每个坐标为 12 位
    integer i;                 // 循环计数器
    reg [7:0] angle;         // 输出角度

    corr2angle test(.x1(x1), .y1(y1), .x2(x2), .y2(y2), .angle(angle)); // 调用 corr2angle 模块
    initial begin
        // 打印标题
        
        $display("Time\t\tx1\t\ty1\t\tx2\t\ty2");

        // 循环生成若干组 (x1, y1) 和 (x2, y2)
        for (i = 0; i < 10; i = i + 1) begin
            // 随机生成坐标值
            x1 = $random % 4096; // 限制到 12 位范围 (0~4095)
            y1 = $random % 4096;
            x2 = $random % 4096;
            y2 = $random % 4096;

            // 打印当前时间和坐标值
            $display("%0t\t%d\t%d\t%d\t%d   %d", $time, x1, y1, x2, y2, angle);
            
            #10; // 每次间隔 10 时间单位
        end

        // 结束模拟
        $finish;
    end
endmodule