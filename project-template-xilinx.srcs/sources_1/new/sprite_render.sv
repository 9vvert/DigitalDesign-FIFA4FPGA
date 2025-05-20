/***********   sprite_render   ************/
// 作用：进行一轮图层渲染，将SDRAM中存储的图片数据放到指定显存区域
// [TODO]有一个想法：考虑到背景层的渲染会占用大量的时间，如果后续卡顿的话，可以提供一种新的方法：
//          每次刷新的时候，并不将整张背景重新拷贝，而是用背景上的一个区域“填补”到原图像的位置
import type_declare::*;
module sprite_render
// 显存参数（后续会将显存坐标映射到具体的SDRAM内存地址）
#(parameter VM_WIDTH = (TEST_DEBUG ? TEST_HSIZE : 1280), VM_HEIGHT =(TEST_DEBUG ? TEST_VSIZE : 720))        
(
    //控制参数
    input sprite_render_ui_clk,
    input ui_rst,
    input mode,     // 0:将线性存储的数据渲染到显存的指定坐标；  1：将背景的某一块补全
                    // 计划：第一次将背景加载到一块和显存等大的地方，此后就从这里来“复制”一块，进行填补
    input render_begin,
    output reg render_end,
    //
    input [29:0] vm_start,      // 该显存开始的地址
    input [11:0] half_img_width,    //[TODO]一定要注意：这里用半宽
    input [11:0] half_img_height,
    input [11:0] hpos,          // 物体在显存中渲染的坐标
    input [11:0] vpos,
    // mode = 0 时， sprite_addr有效
    input [29:0] sprite_addr,    // 图片数据存放的地址（线性存储）
    // mode = 1 时， 下列有效
    // 这种情况只有在背景裁剪的情况下会使用，bg_hpos和bg_vpos和hpos, vpos恒相等
    input [29:0] vm_background_start,   //背景在显存中另外开辟一个区域，和显存等大
    input [11:0] bg_hpos,
    input [11:0] bg_vpos,
    //控制SDRAM
    output reg [1:0] sdram_cmd,          //命令，  0无效，1读取，2写入
    output reg [29:0] operate_addr,      //地址
    output reg [63:0] write_data,
    input [63:0] read_data,
    input cmd_done   
);
    // mode==0
    reg [29:0] src_addr;
    // mode==1
    reg [11:0] src_x;
    reg [11:0] src_y;

    reg [11:0] dst_x;   //目标位置在显存中的坐标
    reg [11:0] dst_y;   //删去中间的dst_addr层，直接用dst_x和dst_y计算
    reg [63:0] sprite_buffer;

    reg [2:0] render_stat;      //渲染状态机
    reg delay_counter;
    
    reg last_cmd_done;

    
    localparam [2:0] IDLE=0, READ=1, WRITE=2, DONE=3;
    always@(posedge sprite_render_ui_clk)begin
        if(ui_rst)begin
            render_stat <= IDLE;
            sprite_buffer <= 64'd0;
            dst_x <= 0;
            dst_y <= 0;
            src_x <= 0;
            src_y <= 0;
            last_cmd_done <= 1'b0;
            delay_counter <= 1'b0;
            render_end <= 1'b0;
        end else begin
            if(render_stat == IDLE)begin
                if(render_begin)begin
                    if(mode)begin
                        src_x <= (bg_hpos >= half_img_width) ? (bg_hpos - half_img_width) : 0;
                        src_y <= (bg_vpos >= 2*half_img_height)? (bg_vpos - 2*half_img_height) : 0;
                    end else begin
                        src_addr <= sprite_addr;
                    end
                    // [TODO] 考虑边界问题，否则可能会溢出
                    dst_x <= (hpos >= half_img_width) ? (hpos - half_img_width) : 0;
                    dst_y <= (vpos >= 2*half_img_height)? (vpos - 2*half_img_height) : 0;
                    render_stat <= READ;
                end
            end else if(render_stat == READ)begin
                sdram_cmd <= 2'd1;      //读取
                if(mode)begin
                    operate_addr <= vm_background_start +2* src_y * VM_WIDTH +2* src_x;
                end else begin
                    operate_addr <= src_addr;
                end
                if( (~last_cmd_done) & cmd_done)begin
                    //读取完毕
                    if(mode)begin
                        if(src_x == bg_hpos + half_img_width -4)begin
                            src_x <= bg_hpos - half_img_width;
                            if(src_y == bg_vpos - 1)begin
                                ;
                            end else begin
                                src_y <= src_y + 1;
                            end
                        end else begin
                            src_x <= src_x + 4;     //每次处理4个像素
                        end
                    end else begin
                        src_addr <= src_addr + 8;   //用完立刻递增
                    end
                    sprite_buffer <= read_data; //数据读入sprite_buffer缓冲
                    render_stat <= WRITE;       //进入写状态
                end
            end else if(render_stat == WRITE)begin
                sdram_cmd <= 2'd2;
                operate_addr <= vm_start + 2*dst_y * VM_WIDTH + 2*dst_x;
                write_data <= sprite_buffer;        //将缓存写入
                if( (~last_cmd_done) & cmd_done)begin
                    //写入完毕
                    if(dst_x == hpos + half_img_width -4)begin
                        dst_x <= hpos - half_img_width;
                        if(dst_y == vpos - 1)begin
                            //已经是最后一行，结束
                            render_end <= 1'b1;
                            render_stat <= DONE;
                        end else begin
                            dst_y <= dst_y + 1;
                            render_stat <= READ;
                        end
                    end else begin
                        dst_x <= dst_x + 4;     //每次处理4个像素
                        render_stat <= READ;
                    end
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
            last_cmd_done <= cmd_done;
        end
    end
endmodule