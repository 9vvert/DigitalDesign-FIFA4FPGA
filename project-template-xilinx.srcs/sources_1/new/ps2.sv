module ps2(
    input  wire ps2_clk,          // 10MHz
    input  wire rst,        // 复位信号，低电平有效
    output [7:0] ret_signal,
    output [7:0] ret_cmd,
    output ret_start,
    output ret_end,
    output wire pmod_io1,    // PMOD 接口引脚 1
    input wire pmod_io2,    // PMOD 接口引脚 2
    output wire pmod_io3,    // PMOD 接口引脚 3
    output wire pmod_io4    // PMOD 接口引脚 4
);
// 分为8帧进行

    assign ret_signal = spi_signal;
    assign ret_cmd = spi_cmd;
    assign ret_start = spi_start;
    assign ret_end = spi_end;

    (* KEEP *)reg spi_start;

    (* KEEP *)reg spi_end;

    (* KEEP *)reg [7:0] spi_cmd;

    (* KEEP *)reg [7:0] spi_signal;

    reg [7:0] ps2_mode;
    reg [7:0] btn_grp1;
    reg [7:0] btn_grp2;
    reg [7:0] rhandle_X;    //模拟值
    reg [7:0] rhandle_Y;
    reg [7:0] lhandle_X;
    reg [7:0] lhandle_Y;
    (* DONT_TOUCH *) spi PS2_1(
        .clk(ps2_clk),         //分频，1MHz时钟
        .rst(rst),
        .pmod_io1(pmod_io1), // MOSI
        .pmod_io2(pmod_io2), // MISO
        .pmod_io3(pmod_io3), // SCLK
        .pmod_io4(pmod_io4),  // CS
        .tx_data(spi_cmd), // 要发送的数据
        .rx_data(spi_signal), // 接收的数据
        .start(spi_start), // 开始发送信号
        .done(spi_end) // 发送完成信号
    );

    reg [2:0] ps2_stat; // ps2线性状态机

    always @(posedge ps2_clk or posedge rst) begin
        if (rst) begin
            ps2_stat <= 3'b0;       // 0代表什么都不做,1\2发送，3接受

        end else begin
            if(ps2_stat == 3'b000) begin
                //第一帧，主机发送0x01，表示开始
                spi_cmd <= 8'h01; 
                spi_start <= 1'b1; 
                //只有当DONE == 1才能进行状态转换；（仅有一个周期，因为在IDLE状态也会设为0）
                // DONE就是一个通知“完成，继续”的信号
                if(spi_end) begin
                    spi_start <= 1'b0; 
                    ps2_stat <= 3'b001; 
                end else begin
                    ps2_stat <= 3'b000; // 状态保持在空闲状态
                end
            end else if (ps2_stat == 3'b001) begin
                //第二帧，主机发送0x42，PS2返回工作模式（红灯/绿灯）
                spi_cmd <= 8'h42;
                spi_start <= 1'b1; 
                if(spi_end) begin
                    spi_start <= 1'b0; 
                    ps2_stat <= 3'b010; 
                    ps2_mode <= spi_signal;
                end else begin
                    ps2_stat <= 3'b001; // 状态保持在发送状态
                end
            end else if (ps2_stat == 3'b010) begin
                //第二帧，发送右侧震动WW值，返回第一组按钮值（按下为0）
                spi_cmd <= 8'h0;       
                spi_start <= 1'b1; 
                if(spi_end) begin
                    spi_start <= 1'b0; 
                    ps2_stat <= 3'b011; 
                    btn_grp1 <= spi_signal;
                end else begin
                    ps2_stat <= 3'b010; // 状态保持在发送状态
                end
            end else if (ps2_stat == 3'b011) begin
                //第四帧：发送左侧震动YY值，返回第二组按钮值（按下为0）
                spi_cmd <= 8'h0;        
                spi_start <= 1'b1; 
                if(spi_end) begin
                    spi_start <= 1'b0; 
                    ps2_stat <= 3'b100; 
                    btn_grp2 <= spi_signal;
                end else begin
                    ps2_stat <= 3'b011; // 状态保持在发送状态
                end
            end else if (ps2_stat == 3'b100) begin
                spi_cmd <= 8'hFF;      //随机值即可  
                spi_start <= 1'b1; 
                if(spi_end) begin
                    spi_start <= 1'b0; 
                    ps2_stat <= 3'b101; 
                    rhandle_X <= spi_signal;
                end else begin
                    ps2_stat <= 3'b100; // 状态保持在发送状态
                end
            end else if (ps2_stat == 3'b101) begin
                spi_cmd <= 8'hEE;      //随机值即可  
                spi_start <= 1'b1; 
                if(spi_end) begin
                    spi_start <= 1'b0; 
                    ps2_stat <= 3'b110; 
                    rhandle_Y <= spi_signal;
                end else begin
                    ps2_stat <= 3'b101; // 状态保持在发送状态
                end
            end else if (ps2_stat == 3'b110) begin
                spi_cmd <= 8'hDD;      //随机值即可  
                spi_start <= 1'b1; 
                if(spi_end) begin
                    spi_start <= 1'b0; 
                    ps2_stat <= 3'b111; 
                    lhandle_X <= spi_signal;
                end else begin
                    ps2_stat <= 3'b110; // 状态保持在发送状态
                end
            end else if (ps2_stat == 3'b111) begin
                spi_cmd <= 8'hCC;      //随机值即可  
                spi_start <= 1'b1; 
                if(spi_end) begin
                    spi_start <= 1'b0; 
                    ps2_stat <= 3'b000; 
                    lhandle_Y <= spi_signal;
                end else begin
                    ps2_stat <= 3'b111; // 状态保持在发送状态
                end
            end else begin
                ps2_stat <= ps2_stat;
            end
        end
    end

    //如果直接使用，因为是在另一个时钟里进行赋值，所以可能提示：没有clock domain而无法添加debug
endmodule