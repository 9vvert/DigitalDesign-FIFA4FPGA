/***********   sprite_render   ************/
// 作用：进行一轮图层渲染，将SDRAM中存储的图片数据放到指定显存区域
// [TODO]有一个想法：考虑到背景层的渲染会占用大量的时间，如果后续卡顿的话，可以提供一种新的方法：
//          每次刷新的时候，并不将整张背景重新拷贝，而是用背景上的一个区域“填补”到原图像的位置
import type_declare::*;
parameter BUF1_START = 0, BUF2_START = 524288;
module line_render
// 更新： 这里将参数写死，只能渲染32*32的图片。将更大的图片渲染转移到background_render.sv中 [TODO]
// 显存参数（后续会将显存坐标映射到具体的SDRAM内存地址）
#(parameter VM_WIDTH = (TEST_DEBUG ? TEST_HSIZE : 1280), VM_HEIGHT =(TEST_DEBUG ? TEST_VSIZE : 720))        
(
    //控制参数
    input line_render_ui_clk,
    input ui_rst,
    input vm_flag,
    input render_begin,
    output reg render_end,
    // dst, SRAM
    input [11:0] hpos,          // 物体在显存中渲染的坐标
    input [11:0] vpos,
    // src, 从SDRAM中读取，存储到reg中
    input [15:0] line_buffer [31:0],     //从0到31，各代表一个像素
    //控制SRAM [TODO] 需要处理奇数时的特殊情况
    output reg sram_io_req,        //读写请求
    output reg [19:0] times,       //读写次数
    output reg wr,                 //是否选择“写”
    output reg [19:0] addr,
    output reg [31:0] din,          // 渲染信息
    input wire [31:0] dout
);
    reg [3:0] render_stat;      //渲染状态机
    reg delay_counter;

    // 其实只需要根据hpos的奇偶性来判断

    localparam [3:0] IDLE=0, READ1=1, READ2=2, WRITE1=3, WRITE2=4, WRITE3=5, PRE_READ=6, PRE_WRITE=7,DONE=8;
    reg [31:0] tmp_line_buffer[16:0];       //用于读取目前的画面，准备17个位置
    reg special_flag;
    reg [4:0] h_counter;     //每次写入4B数据，一共需要16次
    /***** 改良状态机 *****/

    always@(posedge line_render_ui_clk)begin
        if(ui_rst)begin
            render_stat <= IDLE;
            delay_counter <= 1'b0;
            render_end <= 1'b0;
            special_flag <= 0;
            h_counter <= 0;
        end else begin
            if(render_stat == IDLE)begin
                if(render_begin)begin
                    special_flag <= hpos[0];    //奇数，将特殊标记拉高
                    render_stat <= PRE_READ;
                    //////  第一次请求，读数据  ///////
                    wr <= 0;        // [TODO]测试：如果din和wr不同时送达，有什么影响？
                    sram_io_req <= 1;
                end
            end else if(render_stat == PRE_WRITE)begin
                //设置写入的数据、地址等
                times <= special_flag ? 17 : 16;
                addr <= (vm_flag ? BUF2_START : BUF1_START ) + vpos*(VM_WIDTH/2) + (hpos>>1); 
                // 这里需要对din的数据进行处理
                if(special_flag)begin           //奇数情况
                    din[31:16] <= tmp_line_buffer[0][31:16];
                    din[15:0] <= (line_buffer[0] == 'h0) ? tmp_line_buffer[0][15:0] : line_buffer[0];
                end else begin                  //一般情况，如果渲染图形该点像素不是0x00,就覆盖
                    din[31:16] <= (line_buffer[0] == 'h0) ? tmp_line_buffer[0][31:16] : line_buffer[0];
                    din[15:0] <= (line_buffer[1] == 'h0) ? tmp_line_buffer[0][15:0] : line_buffer[1];
                end
                render_stat <= WRITE1;
            end else if(render_stat == WRITE1)begin     // 这里和SRAM内部状态同步
                sram_io_req <= 0;       //请求信号安全复位
                render_stat <= WRITE2;
            end else if(render_stat == WRITE2)begin
                render_stat <= WRITE3;
            end else if(render_stat == WRITE3)begin
                if(h_counter == times - 1)begin
                    //彻底结束
                    h_counter <= 0;
                    render_end <= 1;        //将结束信号拉高
                    render_stat <= DONE;
                end else begin
                    //新的一轮，需要准备下一轮的数据
                    addr <= addr + 1;
                    h_counter <= h_counter + 1;

                    if(special_flag)begin           //奇数情况
                        //[TODO]重点检查以下逻辑
                        if(h_counter == times - 2)begin    //下一轮是最后一个点
                            din[31:16] <= (line_buffer[31] == 'h0) ? tmp_line_buffer[16][31:16] : line_buffer[31];
                            din[15:0] <= tmp_line_buffer[16][15:0];
                        end else begin          //中间，组合
                            din[31:16] <= (line_buffer[2*h_counter+1] == 'h0) ? tmp_line_buffer[h_counter+1][31:16] : line_buffer[2*h_counter-1];
                            din[15:0] <= (line_buffer[2*h_counter+2] == 'h0) ? tmp_line_buffer[h_counter+1][15:0] : line_buffer[2*h_counter];
                        end
                    end else begin                  //一般情况，如果渲染图形该点像素不是0x00,就覆盖
                        din[31:16] <= (line_buffer[2*h_counter+2] == 'h0) ? tmp_line_buffer[h_counter+1][31:16] : line_buffer[2*h_counter+2];
                        din[15:0] <= (line_buffer[2*h_counter+3] == 'h0) ? tmp_line_buffer[h_counter+1][15:0] : line_buffer[2*h_counter+3];
                    end

                    render_stat <= WRITE1;
                end
            end else if(render_stat == PRE_READ)begin       //先读16-17次
                times <= special_flag ? 17 : 16;
                addr <= (vm_flag ? BUF2_START : BUF1_START ) + vpos*(VM_WIDTH/2) + (hpos>>1); 
                render_stat <= READ1;
            end else if(render_stat == READ1)begin
                sram_io_req <= 0;           // 安全复位
                render_stat <= READ2;
            end else if(render_stat == READ2)begin
                tmp_line_buffer[h_counter] <= dout;     //此时值已经稳定
                if(h_counter == times - 1)begin
                    h_counter <= 0;     //重置计数器
                    render_stat <= PRE_WRITE;     // 全部读取完成，可以开始写了
                    /////// 开启第二次请求，这次是写数据 ///////
                    sram_io_req <= 1;
                    wr <= 1;
                end else begin
                    h_counter <= h_counter + 1;
                    addr <= addr + 1;
                    render_stat <= READ1;
                end
            end else begin      // DONE
                if(delay_counter == 0)begin
                    delay_counter <= 1;
                end else begin
                    delay_counter <= 0;
                    render_end <= 1'b0;
                    render_stat <= IDLE;
                end
            end
        end
    end
endmodule