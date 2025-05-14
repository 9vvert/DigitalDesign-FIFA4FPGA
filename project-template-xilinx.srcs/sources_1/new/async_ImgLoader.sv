/******  作用：读取SD卡中的数据，并填写到SDRAM的缓存中  ******/

//  外部使用的时候，设置好in_width, in_height, 然后将load_start拉高一个周期
module async_ImgLoader(
    //数据总信息

    input ui_clk,       // 仍旧使用显存的时钟频率
    input ui_rst,
    input load_start,           //开始加载一个命令
    output reg load_end,        //图片加载结束，可以开始下一次加载
    input [15:0] in_width,         
    input [15:0] in_height,        // 最终读取的数据量为：img_width*img_height*3 bytes
    //SD
    input sd_read_end,
    output sd_read_start,
    input [31:0] sd_start_addr,       // SD卡读取的地址
    output reg [31:0] curr_sd_addr,
    //SDRAM
    output reg sdram_write_start,
    input sdram_write_end,
    input [29:0] sdram_start_addr,
    output reg [29:0] curr_sdram_addr
);
    /**********   状态定义   **********/
    // 执行一轮，可以拷贝512字节
    // JUDGE负责在每一轮开始时进行判断，包括是否有剩余的字节，以及是否够512字节
    localparam [2:0] IDLE = 3'd0, READ_SD1 = 3'd1, WRITE_SDRAM1 = 3'd2, DONE = 3'd3, JUDGE = 3'd4,
    READ_SD2 = 3'd5 ,WRITE_SDRAM2 = 3'd6;
    reg [2:0] loader_stat;
    reg [31:0] remain_bytes;        //剩余需要读的字节数
    //起始即使最后一周期不用读取512字节，让SDRAM读取额外的也没有影响。只要使用的时候及时终止即可
    reg last_sd_read_end;   //用于检测sd_read_end标志的上升和下降
    reg last_sdram_write_end;   //用于检测sd_read_end标志的上升和下降

    //
    reg [7:0] buffer[511:0];        //缓冲区，用来存放从SD卡读取来的数据
    always@(posedge ui_clk)begin
        if(ui_rst)begin
            loader_stat <= IDLE;
            remain_bytes <= 32'd0;
        end else begin
            //每个周期都会检测
            if(loader_stat == IDLE)begin
                if(load_start)begin
                    loader_stat <= JUDGE;
                    remain_bytes <= in_width*in_height*3;   //图片的所有数据：宽*高*3
                    curr_sd_addr <= sd_start_addr;
                    curr_sdram_addr <= sdram_start_addr;
                end
            end else if(loader_stat == JUDGE)begin
                if(remain_bytes > 0)begin
                    if(remain_bytes >= 512)begin
                        remain_bytes <= remain_bytes - 512;
                    end else begin
                        remain_bytes <= 0;
                    end
                    loader_stat <= READ_SD1; //开启新的一个周期
                end else begin
                    load_end <= 1'b1;       
                    loader_stat <= DONE;    //结束
                end
            end else if(loader_stat == READ_SD1)begin
                // 读取SD卡：先将sd_read_start拉高足够长时间（直到sd_read_end变为高电平，即扇区读取完毕）
                sd_read_start <= 1'b1;
                loader_stat <= READ_SD2;
            end else if(loader_stat == READ_SD2)begin
                //等待，检测sd_read_end的上升和下降
                if(last_sd_read_end == 1'b0 && sd_read_end == 1'b1)begin
                    sd_read_start <= 1'b0;
                end
                if(last_sd_read_end == 1'b1 && sd_read_end == 1'b0)begin
                    loader_stat <= WRITE_SDRAM1; 
                end
            end else if(loader_stat == WRITE_SDRAM1)begin
                sdram_write_start <= 1'b1;
                loader_stat <= WRITE_SDRAM2;
            end else if(loader_stat == WRITE_SDRAM2)begin
                if(last_sdram_write_end == 1'b0 && sdram_write_end == 1'b1)begin
                    sdram_write_end <= 1'b0;
                end
                if(last_sdram_write_end == 1'b1 && sdram_write_end == 1'b0)begin
                    loader_stat <= WRITE_SDRAM1; 
                end
            end else begin      //DONE
                load_end <= 1'b0;
                loader_stat <= IDLE;        //准备下一轮
            end
            last_sdram_write_end = sdram_write_end;
            last_sd_read_end = sd_read_end;
        end
    end

endmodule