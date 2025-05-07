module cmd(
    input  wire ps2_clk,          // 100kHz， 10us一次
    input  wire rst,        // 复位信号，高电平有效
    output wire pmod_io1,    // MOSI
    input wire pmod_io2,    // MISO
    output wire pmod_io3,    // SCLK    //手动控制，不再使用外部时钟
    output reg pmod_io4    // CS
    // 对外接口
    
);
// 这里尽量做好ps2手柄的信号解码、角度转换、消抖等操作
    

    reg [7:0] ps2_mode;
    reg [7:0] btn_grp1;
    reg [7:0] btn_grp2;
    reg [7:0] rhandle_X;
    reg [7:0] rhandle_Y;
    reg [7:0] lhandle_X;
    reg [7:0] lhandle_Y;
    reg ready; 

    ps2 u_ps2(
        // .debug_number(number),
        .ps2_clk(ps2_clk),          // 10kHz
        .rst(rst) ,      // 复位信号，低电平有效
        .ps2_mode(ps2_mode), // 模式
        .btn_grp1(btn_grp1), // 按键组1
        .btn_grp2(btn_grp2), // 按键组2
        .rhandle_X(rhandle_X), // 右手柄 X 轴
        .rhandle_Y(rhandle_Y), // 右手柄 Y 轴
        .lhandle_X(lhandle_X), // 左手柄 X 轴
        .lhandle_Y(lhandle_Y), // 左手柄 Y 轴
        .ready(ready), // 是否准备好，1表示准备好，0表示正在读取数据
        .pmod_io1(pmod_io1), // MOSI
        .pmod_io2(pmod_io2), // MISO
        .pmod_io3(pmod_io3), // SCLK
        .pmod_io4(pmod_io4)  // CS
    );
    // !!!!!!!!!!语法上，即使最后多加了一个逗号也会报错！
    always @(posedge ps2_clk) begin
        if(rst) begin
            number <= 32'd0;
            //因为ready是在内部输出的，所以这里不应该再进行初始化
        end else if(ready)begin
            //测试：ready=1代表这一个周期的手柄信号可以读取，
            number[7:0] <= btn_grp1;
            number[15:8] <= btn_grp2;
            number[23:16] <= rhandle_X;
            number[31:24] <= rhandle_Y;
        end else begin
            number <= number;
        end
    end

endmodule