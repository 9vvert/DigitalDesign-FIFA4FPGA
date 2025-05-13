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
    output reg [7:0] red,         // output reg是时序逻辑，output wire是组合逻辑
    output reg [7:0] green,
    output reg [7:0] blue,
    output wire data_enable
);

    reg [23:0] rom_val;
    reg [9:0] rom_addr;
    
    parameter IMG_WIDTH = 19, IMG_HEIGHT = 33;
    initial begin
        rom_val <= 'b0;
        hdata = 'b0;
        vdata = 'b0;
        red = 'b0;
        green = 'b0;
        blue = 'b0;   //语法：自动赋0，不需要前面的位数
        rom_addr = 'b0;
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

    
    blk_mem_gen_0 rom(
        .clka(clk),
        .ena(data_enable),
        .addra(rom_addr),
        .douta(rom_val)
    );
    // hsync & vsync & blank
    assign hsync = ((hdata >= HFP) && (hdata < HSP)) ? HSPP : !HSPP;
    assign vsync = ((vdata >= VFP) && (vdata < VSP)) ? VSPP : !VSPP;
    assign data_enable = ((hdata < HSIZE) && (vdata < VSIZE));

    wire img_enable;
    assign img_enable = ((hdata < IMG_WIDTH) && (vdata < IMG_HEIGHT));
    //注意区分hdata/vdata和hsync/vsync： 前者是纯粹的计数器，而后者代表了同步信号的高电平和低电平
    //为什么要加上 C_H_SYNC_PULSE 和 C_H_BACK_PORCH？
    //因为 显示器开始“真正显示图像”的位置，并不是从 R_h_cnt = 0 开始的，而是从 同步信号（HSYNC）和回扫间隔（Back Porch）之后 才开始！

    always @ (posedge clk)
    begin
        if(data_enable)begin
            if(img_enable) begin
                red <= rom_val[23:16];
                green <= rom_val[15:8];
                blue <= rom_val[7:0];
                if(rom_addr == IMG_WIDTH*IMG_HEIGHT-1)begin
                    rom_addr <= 10'd0;
                end else begin
                    rom_addr <= rom_addr+10'd1;
                end
            end else begin
                red <= 8'h88;
                green <= 8'h44;
                blue <= 8'h33;
            end
        end
        
    end 
endmodule
