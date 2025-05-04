// 对外暴露的使用接口：模式（红灯/绿灯），是否准备好，具体的案件命令
module ps2_new(
    input  wire ps2_clk,          // 100kHz， 10us一次
    input  wire rst,        // 复位信号，低电平有效
    output wire [31:0] debug_number,
    output reg [7:0] ps2_mode,
    output reg [7:0] btn_grp1,
    output reg [7:0] btn_grp2,
    output reg [7:0] rhandle_X,    
    output reg [7:0] rhandle_Y,
    output reg [7:0] lhandle_X,
    output reg [7:0] lhandle_Y,
    output reg ready, // 是否准备好，1表示准备好，0表示正在读取数据

    output wire pmod_io1,    // MOSI
    input wire pmod_io2,    // MISO
    output wire pmod_io3,    // SCLK    //手动控制，不再使用外部时钟
    output reg pmod_io4    // CS
);
// 分为8帧进行

    reg spi_start;
    reg spi_end;
    reg [7:0] spi_cmd;
    reg [7:0] spi_dat;

    spi_new u_spi(
        .clk(ps2_clk),
        .rst(rst),
        .pmod_io1(pmod_io1),
        .pmod_io2(pmod_io2),
        .pmod_io3(pmod_io3),
        .cmd(spi_cmd),
        .dat(spi_dat),
        .start(spi_start),
        .done(spi_end)
    );

    reg [3:0] ps2_stat; // ps2线性状态机
    reg first_flag;

    reg [31:0] delay_counter;
    reg [31:0] interval_counter;

    assign debug_number[7:0] = btn_grp1;
    assign debug_number[15:8] = btn_grp2;
    assign debug_number[23:16] = rhandle_X;
    assign debug_number[31:24] = rhandle_Y;
    always @(posedge ps2_clk) begin
        //经过实验，如果不加这两行，数码管似乎不会正常显示！！！非常奇怪v
        if (rst) begin
            ps2_stat <= 4'd0;
            pmod_io4 <= 1'b1; 
            first_flag <= 1'b1;
            delay_counter <= 32'd0;
            interval_counter <=32'd0;
        end else if(delay_counter < 32'd1000000) begin
            delay_counter <= delay_counter + 32'd1;
        end else if(interval_counter < 32'd100) begin
            interval_counter <= interval_counter + 32'd1;
        end else begin
            if(ps2_stat == 4'd0) begin
                //第0帧，发送0x01，接受随机值
                spi_cmd <= 8'h01;
                if(first_flag)begin
                    first_flag <= 1'b0;
                    pmod_io4 <= 1'b0;   //拉低CS 
                    spi_start <= 1'b1;
                end else begin
                    spi_start <= 1'b0;
                end
                if(spi_end) begin
                    first_flag <= 1'b1;
                    ps2_stat <= 4'd1;
                end
            end else if (ps2_stat == 4'd1) begin
                //第一帧，发送0x42，返回ID(模式)
                spi_cmd <= 8'h42;
                if(first_flag)begin
                    first_flag <= 1'b0;
                    spi_start <= 1'b1;
                end else begin
                    spi_start <= 1'b0;
                end
                if(spi_end) begin
                    ps2_mode <= spi_dat;
                    first_flag <= 1'b1;
                    ps2_stat <= 4'd2;
                end
            end else if (ps2_stat == 4'd2) begin
                //第二帧，发送随机值，返回0x5A
                spi_cmd <= 8'h00;
                if(first_flag)begin
                    first_flag <= 1'b0;
                    spi_start <= 1'b1;
                end else begin
                    spi_start <= 1'b0;
                end
                if(spi_end) begin
                    first_flag <= 1'b1;
                    ps2_stat <= 4'd3;
                end
            end else if (ps2_stat == 4'd3) begin
                //第三帧，发送震动值，返回grp1_button
                spi_cmd <= 8'h00;
                if(first_flag)begin
                    first_flag <= 1'b0;
                    spi_start <= 1'b1;
                end else begin
                    spi_start <= 1'b0;
                end
                if(spi_end) begin
                    
                    btn_grp1 <= spi_dat;
                    first_flag <= 1'b1;
                    ps2_stat <= 4'd4;
                end
            end else if (ps2_stat == 4'd4) begin
                //第四帧，发送震动值，返回grp2_button
                spi_cmd <= 8'h00;
                if(first_flag)begin
                    first_flag <= 1'b0;
                    spi_start <= 1'b1;
                end else begin
                    spi_start <= 1'b0;
                end
                if(spi_end) begin
                    btn_grp2 <= spi_dat;
                    first_flag <= 1'b1;
                    ps2_stat <= 4'd5;
                end
            end else if (ps2_stat == 4'd5) begin
                //第五帧，发送随机值，返回RX
                spi_cmd <= 8'h00;
                if(first_flag)begin
                    first_flag <= 1'b0;
                    spi_start <= 1'b1;
                end else begin
                    spi_start <= 1'b0;
                end
                if(spi_end) begin
                    rhandle_X <= spi_dat;
                    first_flag <= 1'b1;
                    ps2_stat <= 4'd6;
                end
            end else if (ps2_stat == 4'd6) begin
                //第六帧，发送随机值，返回RY
                spi_cmd <= 8'h00;
                if(first_flag)begin
                    first_flag <= 1'b0;
                    spi_start <= 1'b1;
                end else begin
                    spi_start <= 1'b0;
                end
                if(spi_end) begin
                    rhandle_Y <= spi_dat;
                    first_flag <= 1'b1;
                    ps2_stat <= 4'd7;
                end
            end else if (ps2_stat == 4'd7) begin
                //第七帧，发送随机值，返回LX
                spi_cmd <= 8'h00;
                if(first_flag)begin
                    first_flag <= 1'b0;
                    spi_start <= 1'b1;
                end else begin
                    spi_start <= 1'b0;
                end
                if(spi_end) begin
                    lhandle_X <= spi_dat;
                    first_flag <= 1'b1;
                    ps2_stat <= 4'd8;
                end
            end else if (ps2_stat == 4'd8) begin
                //第八帧，发送随机值，返回LY
                spi_cmd <= 8'h00;
                if(first_flag)begin
                    first_flag <= 1'b0;
                    spi_start <= 1'b1;
                end else begin
                    spi_start <= 1'b0;
                end
                if(spi_end) begin
                    interval_counter <= 32'd0;
                    lhandle_Y <= spi_dat;
                    first_flag <= 1'b1;
                    pmod_io4 <= 1'b1;   //重新拉高CS
                    ps2_stat <= 4'd0;
                end
            end else begin
                ps2_stat <= ps2_stat;
            end
        end
    end

    //如果直接使用，因为是在另一个时钟里进行赋值，所以可能提示：没有clock domain而无法添加debug
endmodule