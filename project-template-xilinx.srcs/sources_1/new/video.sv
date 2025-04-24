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
    output reg [7:0] red,        
    output reg [7:0] green,
    output reg [7:0] blue,
    output wire data_enable
);

    wire [23:0] rom_color; // 颜色数据
    reg [18:0] rom_addr; // 颜色数据地址

    initial begin
        hdata = 'b0;
        vdata = 'b0;
        red = 'b0;
        green = 'b0;
        blue = 'b0;   
        rom_addr = 'b0;
    end
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
            if (vdata == (VMAX - 1))        // 当一行扫描完了开始下一行
                vdata <= 0;
            else
                vdata <= vdata + 1;
        end
    end

    parameter IMAGE_WIDTH = 244; // 图像宽度
    parameter IMAGE_HEIGHT = 207; // 图像高度
    parameter IMAGE_SIZE = IMAGE_WIDTH * IMAGE_HEIGHT; 
    // hsync & vsync & blank
    assign hsync = ((hdata >= HFP) && (hdata < HSP)) ? HSPP : !HSPP;
    assign vsync = ((vdata >= VFP) && (vdata < VSP)) ? VSPP : !VSPP;
    assign data_enable = ((hdata < HSIZE) & (vdata < VSIZE));
    assign picture_enable = ((hdata < IMAGE_WIDTH) & (vdata < IMAGE_HEIGHT)); // 画图使能信号
    //注意区分hdata/vdata和hsync/vsync 前者是是纯粹的计数器，后者代表了同步信号的高电平和低电平
    always @ (posedge clk)
    begin
        if(picture_enable) begin
            rom_addr <= vdata * IMAGE_WIDTH + hdata;
            red <= rom_color[23:16]; // 取出红色分量
            green <= rom_color[15:8]; 
            blue <= rom_color[7:0];  
            // if(rom_addr == IMAGE_SIZE - 1) begin
            //     rom_addr <= 'b0; // 只要有递增的地方，一定要注意清空
            // end else begin
            //     rom_addr <= rom_addr + 1; // 递增地址
            // end
        end else begin
            red <= 'b0;
            green <= 'b0;
            blue <= 'b0;  
            rom_addr <= rom_addr;
        end
    end 

    blk_mem_gen_0 color_rom (       //这种格式就是调用模块执行
        .clka(clk),
        .ena(picture_enable), // 使能端，只读取合适范围内的数据
        .addra(rom_addr), //    颜色地址
        .douta(rom_color) // output [15 : 0] douta
    );
endmodule
