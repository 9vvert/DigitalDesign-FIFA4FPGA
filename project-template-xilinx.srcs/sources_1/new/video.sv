`timescale 1ns / 1ps
/*****************   video.sv  *****************/
// 作用：通过RAM实现显存的二级缓冲

module video
//这里是接受的参数，在mod.top里已经赋值过了，下面的应该是缺省参数，填错了并不影响
#(parameter WIDTH = 12, HSIZE = 1280, HFP = 1390, HSP = 1430, HMAX = 1650, VSIZE = 720, VFP = 725, VSP = 730, VMAX = 750, HSPP = 1, VSPP = 1)
(
    //和显存的交互
    input wire ui_clk,
    //[TODO]对fill_batch进行一层同步
    output reg fill_batch,  //拉高这个信号表示需要填充40KB的缓存数据
    input [31:0] write_data,    //显存通过这三个信号来写入数据
    input [14:0] write_addr,
    input write_enable,
    
    //和HDMI的交互
    input wire clk,
    output wire hsync,
    output wire vsync,
    output reg [WIDTH - 1:0] hdata,
    output reg [WIDTH - 1:0] vdata,
    output [7:0] red,         // output reg是时序逻辑，output wire是组合逻辑
    output [7:0] green,
    output [7:0] blue,
    output wire data_enable
);

    logic [WIDTH - 1:0] next_hdata;
    logic [WIDTH - 1:0] next_vdata;

    localparam READ_SKIP = 20480;           // 和RAM容量有关，不需要随着显示屏的大小改变
    localparam WRITE_SKIP = 10240;
    wire [15:0] read_ram_addr;
    wire [14:0] write_ram_addr;

    wire [15:0] pixel_data;     // 实时连接RAM的输出端口
    reg ram_flag;       // 如果为0，则读取0-40KB，写到40-80K ; 如果为1则交换
    blk_mem_gen_1 u_ram(
        //WRITE
        .clka(ui_clk),
        .ena(1'b1),
        .wea(write_enable),         //用来写
        .addra(write_ram_addr),
        .dina(write_data),
        //READ
        .clkb(clk),
        .enb(1'b1),              //持续读取
        .addrb(read_ram_addr),
        .doutb(pixel_data)
    );

    initial begin
        ram_flag = 'b0;
        hdata = 'b0;
        vdata = 'b0;
    end


    // 交换batch，使用显存时钟的逻辑
    // 每16行进行一次交换
    // [TODO]以后测试的时候，如果修改的分辨率，一定要保持单次读取batch是16行或者其倍数
    reg [WIDTH - 1:0] last_hdata; 
    reg [1:0] fill_batch_cnt;
    always @(posedge clk) begin
        if ((vdata[3:0]==15) && (vdata < VSIZE) && (last_hdata < HSIZE) && (hdata >= HSIZE)) begin
            ram_flag <= ~ram_flag;      //交换batch
            fill_batch_cnt <= 2'b10;
        end else if (fill_batch_cnt != 0) begin
            fill_batch_cnt <= fill_batch_cnt - 1; 
        end
        last_hdata <= hdata;
    end
    always @(posedge clk) begin
        fill_batch <= (fill_batch_cnt != 0);    // fill_batch信号会保持多个hdmi_clk周期
    end

    // 将clk时钟域下的ram_flag同步到ui_clk下
    reg ram_flag_clk1, ram_flag_clk2;
    always @(posedge ui_clk) begin
        ram_flag_clk1 <= ram_flag;
        ram_flag_clk2 <= ram_flag_clk1;
    end

    // 可能是这里导致了时序问题？ 
    assign read_ram_addr = (ram_flag ? READ_SKIP : 0) + HSIZE * next_vdata[3:0] + next_hdata;
    assign write_ram_addr = (ram_flag_clk2 ? 0 : WRITE_SKIP) + write_addr;       // 在输入的基础上增加一层基地址变换
    //[TODO]这里的大小端还需要后续测试
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

    
    
    // next_hdata & next_vdata
    // always_comb begin
    //     if(hdata >= HSIZE-1)begin
    //         next_hdata = 0;
    //         if(next_vdata == 15)begin       // 需要增加一个对next_vdata的同步逻辑
    //             //交换batch
    //             next_vdata = 0;
    //         end else begin
    //             next_vdata = next_hdata + 1;    
    //         end
    //     end else begin
    //         next_vdata = next_vdata;
    //         next_hdata = hdata + 1;        //使用当前的hdata + 1
    //     end
    // end


    always_comb begin
        // --- 1. 计算下一个像素坐标 ---
        if (hdata < HSIZE - 2) begin
            next_hdata = hdata + 2;
            if(vdata < VSIZE)begin
                next_vdata = vdata;
            end else begin
                next_vdata = 0;
            end
        end else if(hdata == HMAX - 1)begin     //一行的最后，这种情况下，需要预测下一行的第二个像素
            next_hdata = 1;
            if(vdata < VSIZE - 1)begin
                next_vdata = vdata + 1;
            end else begin
                next_vdata = 0;
            end

        end else begin
            next_hdata = 0;
            if(vdata < VSIZE - 1)begin
                next_vdata = vdata + 1;
            end else begin
                next_vdata = 0;
            end
        end

    end

    //hsync/vsync ：用于提示HDMI切换到下一个像素
    assign hsync = ((hdata >= HFP) && (hdata < HSP)) ? HSPP : !HSPP;
    assign vsync = ((vdata >= VFP) && (vdata < VSP)) ? VSPP : !VSPP;
    assign data_enable = ((hdata < HSIZE) && (vdata < VSIZE));
    assign red = data_enable ? ({pixel_data[15:11], pixel_data[15:13]}) : 0;
    assign green = data_enable ? ({pixel_data[10:5], pixel_data[10:9]}) : 0;
    assign blue = data_enable ? ({pixel_data[4:0], pixel_data[4:2]}) : 0;
    // always @(posedge clk)begin
    //     // 只需要根据当前的hdata和vdata，计算出“下一个要获得的像素地址”即可
    //     // 每个ram batch能够提供16行的缓存

    // end
endmodule
