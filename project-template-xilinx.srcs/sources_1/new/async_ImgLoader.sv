/******  作用：读取SD卡中的数据，并填写到SDRAM的缓存中  ******/

//  外部使用的时候，设置好in_width, in_height, 然后将load_start拉高一个周期
//  这里使用的是显存数据

//  外界需要确保async_ImgLoader使用的时候，SDRAM已经初始化完毕
module async_ImgLoader(
    //数据总信息
    // output reg [31:0]debug_number,
    input ui_clk,       // 仍旧使用显存的时钟频率
    input ui_rst,
    input load_start,           //开始加载一个命令
    output reg load_end,        //图片加载结束，可以开始下一次加载
    input [11:0] in_width,         
    input [11:0] in_height,        // 最终读取的数据量为：img_width*img_height*3 bytes
    input [31:0] sd_start_addr,    // SD卡图片的起始地址
    input [29:0] sdram_start_addr,  // SDRAM待写入的起始地址
    //SD
    input loader_sd_read_end,
    output reg loader_sd_read_start,
    output reg [31:0] loader_curr_sd_addr,
    input [7:0] loader_sd_buffer [511:0],      // 从sd卡读取的数据
    //SDRAM
    input loader_sdram_write_end,
    // 改了外层的，竟然忘记改里面这里的了，草
    output reg [1:0] loader_sdram_cmd,           // SDRAM输出命令，这里仅仅使用2来写入
    output reg [29:0] loader_curr_sdram_addr,      // SDRAM输出的地址
    output reg [63:0] loader_sdram_buffer,          // 向SDRAM输出的数据
    output reg [27:0] loader_info
);
    /**********   状态定义   **********/
    // 执行一轮，可以拷贝512字节
    // JUDGE负责在每一轮开始时进行判断，包括是否有剩余的字节，以及是否够512字节
    localparam [2:0] IDLE = 3'd0, JUDGE = 3'd1, SD_RD = 3'd2, SDRAM_WR = 3'd3, DONE = 3'd4;
    reg [2:0] loader_stat;
    reg [31:0] remain_bytes;        //剩余需要读的字节数
    //起始即使最后一周期不用读取512字节，让SDRAM读取额外的也没有影响。只要使用的时候及时终止即可
    reg last_sd_read_end;   //用于检测sd_read_end标志的上升和下降
    reg last_sdram_write_end;   //用于检测sd_read_end标志的上升和下降

    integer i;
    reg [63:0] delay_show_counter;      //每隔一秒将sdram接受的数据显示
    //
    reg [7:0] buffer[511:0];        //缓冲区，用来存放从SD卡读取来的数据
    reg [6:0] sector_counter;    //每一个扇区需要读取64次
    reg done_delay_counter;         //用于最后延时释放load_done信号
    always@(posedge ui_clk)begin
        if(ui_rst)begin
            done_delay_counter <= 0;
            sector_counter <= 0;
            loader_stat <= IDLE;
            remain_bytes <= 32'd0;
            done_delay_counter <= 1'b0;
            loader_info <= 0;
            delay_show_counter <= 64'd0;
            // debug_number <= 32'd0;
        end else begin
            //每个周期都会检测
            if(loader_stat == IDLE)begin
                if(load_start)begin
                    loader_stat <= JUDGE;
                    remain_bytes <= in_width*in_height*2;   //图片的所有数据：宽*高*2 (使用RGB565)
                    loader_curr_sd_addr <= sd_start_addr;
                    loader_curr_sdram_addr <= sdram_start_addr;
                end
                // 下面导致全部错位
            end else if(loader_stat == JUDGE)begin
                if(remain_bytes > 0)begin
                    if(remain_bytes >= 512)begin                // 在准备素材的时候，保证数据大小是512的倍数，这里可以不处理特殊情况
                        remain_bytes <= remain_bytes - 512;
                    end
                    loader_info[3:0] <= loader_info[3:0] + 1;
                    loader_stat <= SD_RD; //开启新的一个周期
                end else begin
                    load_end <= 1'b1;       //[TODO]延迟释放    
                    loader_stat <= DONE;    //结束
                end
            end else if(loader_stat == SD_RD)begin
                // 读取SD卡：先将sd_read_start拉高足够长时间（直到sd_read_end变为高电平，即扇区读取完毕）
                loader_sd_read_start <= 1'b1;
                if( (~last_sd_read_end) & loader_sd_read_end)begin
                    loader_curr_sd_addr <= loader_curr_sd_addr + 512;   //在读取完毕后再开始更新
                    loader_info[7:4] <=loader_info[7:4] + 1;
                    for (i = 0; i < 512; i = i + 1) begin
                        buffer[i] <= loader_sd_buffer[i];
                    end
                    loader_sd_read_start <= 1'b0;
                    loader_stat <= SDRAM_WR;
                    sector_counter <= 'd0;
                end
            end else if(loader_stat == SDRAM_WR)begin
                loader_sdram_buffer[63:56] <= buffer[8*sector_counter];
                loader_sdram_buffer[55:48] <= buffer[8*sector_counter+1];
                loader_sdram_buffer[47:40] <= buffer[8*sector_counter+2];
                loader_sdram_buffer[39:32] <= buffer[8*sector_counter+3];
                loader_sdram_buffer[31:24] <= buffer[8*sector_counter+4];
                loader_sdram_buffer[23:16] <= buffer[8*sector_counter+5];
                loader_sdram_buffer[15:8] <= buffer[8*sector_counter+6];
                loader_sdram_buffer[7:0] <= buffer[8*sector_counter+7];
                // debug: 先等4秒，每次展示2个字节，然后才开始写
                
                loader_sdram_cmd <= 2;
                if( (~last_sdram_write_end) & loader_sdram_write_end)begin   //捕捉上升时刻
                    loader_info[23:8] <= loader_info[23:8] + 1;
                    loader_sdram_cmd <= 0;      // 及时撤销命令 
                    sector_counter <= sector_counter + 'd1;
                    delay_show_counter <= 64'd0;
                    loader_curr_sdram_addr <= loader_curr_sdram_addr + 8;
                    // 2025/5/15发现的第三个错误，这里不应该用512！是64，否则会死循环
                    if(sector_counter == 63)begin
                        loader_stat <= JUDGE;   //开启下一个扇区
                    end else begin
                        loader_stat <= SDRAM_WR;    //在开启下一轮写之前，可能需要延时
                                                    //更新：似乎不需要延时，因为上面检测的是上升沿，而不是单纯的电平高低
                    end
                end

            end else begin      //DONE
                if(done_delay_counter == 1'b0)begin
                    done_delay_counter <= 1'b1;
                end else begin
                    done_delay_counter <= 1'b0; //复位
                    load_end <= 1'b0;
                    loader_stat <= IDLE;        //准备下一轮
                end
            end
            last_sdram_write_end <= loader_sdram_write_end;
            last_sd_read_end <= loader_sd_read_end;
        end
    end

endmodule