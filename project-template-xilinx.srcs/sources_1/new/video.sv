`timescale 1ns / 1ps
//
// WIDTH: bits in register hdata & vdata
// HSIZE: horizontal size of visible field 
// HFP: horizontal front of pulse
// HSP: horizontal stop of pulse
// HMAX: horizontal max size of value
// VSIZE: vertical size of visible field 
// VFP: vertical front of pulse
// VSP: vertical stop of pulse
// VMAX: vertical max size of value
// HSPP: horizontal synchro pulse polarity (0 - negative, 1 - positive)
// VSPP: vertical synchro pulse polarity (0 - negative, 1 - positive)
//
module video
//这里是接受的参数，在mod.top里已经赋值过了，下面的应该是缺省参数，填错了并不影响
#(parameter WIDTH = 12, HSIZE = 640, HFP = 16, HSP = 48, HMAX = 6, VSIZE = 480, VFP = 10, VSP = 33, VMAX = 6, HSPP = 96, VSPP = 2)
(
    input wire clk,
    output wire hsync,
    output wire vsync,
    output reg [WIDTH - 1:0] hdata,
    output reg [WIDTH - 1:0] vdata,
    input reg[7:0] btn_grp1,
    input reg[7:0] btn_grp2, // 按键组2
    input reg[7:0] rhandle_X, // 右手柄 X 轴
    input reg[7:0] rhandle_Y, // 右手柄 Y 轴
    input reg[7:0] lhandle_X, // 左手柄 X 轴
    input reg[7:0] lhandle_Y, // 左手柄 Y 轴
    output reg [7:0] red,         // output reg是时序逻辑，output wire是组合逻辑
    output reg [7:0] green,
    output reg [7:0] blue,
    output wire data_enable
);

    parameter  BAR_WIDTH   =   HSIZE / 8  ; // 每个彩条的宽度
    parameter BATCH_HEIGTH = VSIZE / 3; // 每个彩条的高度

    initial begin
        hdata = 'b0;
        vdata = 'b0;
        red = 'b0;
        green = 'b0;
        blue = 'b0;   //语法：自动赋0，不需要前面的位数
    end
    // 初始的水平、竖直计数器

    // hdata
    always @ (posedge clk)
    begin
        if (hdata == (HMAX - 1))
            hdata <= 0;
        else
            hdata <= hdata + 1;
    end

    // vdata
    always @ (posedge clk)
    begin
        if (hdata == (HMAX - 1)) 
        begin
            if (vdata == (VMAX - 1))        // 当一行扫描完了才开始下一行
                vdata <= 0;
            else
                vdata <= vdata + 1;
        end
    end

    // hsync & vsync & blank
    assign hsync = ((hdata >= HFP) && (hdata < HSP)) ? HSPP : !HSPP;
    assign vsync = ((vdata >= VFP) && (vdata < VSP)) ? VSPP : !VSPP;
    assign data_enable = ((hdata < HSIZE) & (vdata < VSIZE));

    //注意区分hdata/vdata和hsync/vsync： 前者是纯粹的计数器，而后者代表了同步信号的高电平和低电平
    //为什么要加上 C_H_SYNC_PULSE 和 C_H_BACK_PORCH？
    //因为 显示器开始“真正显示图像”的位置，并不是从 R_h_cnt = 0 开始的，而是从 同步信号（HSYNC）和回扫间隔（Back Porch）之后 才开始！

    always @ (posedge clk)
    begin
        if(data_enable) begin
            if (hdata < (BAR_WIDTH)) begin
                if(vdata < (BATCH_HEIGTH)) begin
                    if(btn_grp1[0] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else if(vdata < (BATCH_HEIGTH * 2)) begin
                    if(btn_grp2[0] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else if(vdata < (BATCH_HEIGTH * 3)) begin
                    red = rhandle_X;
                    green = rhandle_X;
                    blue = rhandle_X;
                end else begin
                    red <= 8'h0F;
                    green <= 8'h0F;
                    blue <= 8'h0F; 
                end
            end else if (hdata < (BAR_WIDTH * 2)) begin
                if(vdata < (BATCH_HEIGTH)) begin
                    if(btn_grp1[1] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else if(vdata < (BATCH_HEIGTH * 2)) begin
                    if(btn_grp2[1] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else if(vdata < (BATCH_HEIGTH * 3)) begin
                    red = rhandle_Y;
                    green = rhandle_Y;
                    blue = rhandle_Y;
                end else begin
                    red <= 8'h0F;
                    green <= 8'h0F;
                    blue <= 8'h0F; 
                end
            end else if (hdata < (BAR_WIDTH * 3)) begin
                if(vdata < (BATCH_HEIGTH)) begin
                    if(btn_grp1[2] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else if(vdata < (BATCH_HEIGTH * 2)) begin
                    if(btn_grp2[2] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else if(vdata < (BATCH_HEIGTH * 3)) begin
                    red = lhandle_X;
                    green = lhandle_X;
                    blue = lhandle_X;
                end else begin
                    red <= 8'h0F;
                    green <= 8'h0F;
                    blue <= 8'h0F; 
                end
            end else if (hdata < (BAR_WIDTH * 4)) begin
                if(vdata < (BATCH_HEIGTH)) begin
                    if(btn_grp1[3] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else if(vdata < (BATCH_HEIGTH * 2)) begin
                    if(btn_grp2[3] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else if(vdata < (BATCH_HEIGTH * 3)) begin
                    red = lhandle_Y;
                    green = lhandle_Y;
                    blue = lhandle_Y;
                end else begin
                    red <= 8'h0F;
                    green <= 8'h0F;
                    blue <= 8'h0F; 
                end
            end else if (hdata < (BAR_WIDTH * 5)) begin
                if(vdata < (BATCH_HEIGTH)) begin
                    if(btn_grp1[4] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else if(vdata < (BATCH_HEIGTH * 2)) begin
                    if(btn_grp2[4] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else begin
                    red <= 8'h0F;
                    green <= 8'h0F;
                    blue <= 8'h0F; 
                end
            end else if (hdata < (BAR_WIDTH * 6)) begin
                if(vdata < (BATCH_HEIGTH)) begin
                    if(btn_grp1[5] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else if(vdata < (BATCH_HEIGTH * 2)) begin
                    if(btn_grp2[5] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else begin
                    red <= 8'h0F;
                    green <= 8'h0F;
                    blue <= 8'h0F; 
                end
            end else if (hdata < (BAR_WIDTH * 7)) begin
                if(vdata < (BATCH_HEIGTH)) begin
                    if(btn_grp1[6] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else if(vdata < (BATCH_HEIGTH * 2)) begin
                    if(btn_grp2[6] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else begin
                    red <= 8'h0F;
                    green <= 8'h0F;
                    blue <= 8'h0F; 
                end
            end else begin
                if(vdata < (BATCH_HEIGTH)) begin
                    if(btn_grp1[7] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else if(vdata < (BATCH_HEIGTH * 2)) begin
                    if(btn_grp2[7] == 1'b1) begin
                        red <= 8'hFF;    
                        green <= 8'hFF;
                        blue <= 8'hFF;
                    end else begin
                        red <= 8'h35;
                        green <= 8'h35;
                        blue <= 8'h35;   // 黑色分量，关闭显示
                    end
                end else begin
                    red <= 8'h0F;
                    green <= 8'h0F;
                    blue <= 8'h0F; 
                end
            end
        end else begin
            red <= 'b0;
            green <= 'b0;
            blue <= 'b0;   // 黑色分量，关闭显示
        end
    end 
endmodule
