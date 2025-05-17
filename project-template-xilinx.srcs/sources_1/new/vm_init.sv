// 负责将图片资源加载到SDRAM中，规划每一个显存资源的位置，定义描述符
// 负责规划SDRAM的总区域

// 每个图片描述符都是一个数字，代表着：该图片存放在SD卡的某个扇区中，而且乘以512就是SDRAM中的存放位置

parameter [19:0] IMG_INDEX [4:0] = {
    20'd10, 20'd20, 20'd30, 20'd40, 20'd50
};
parameter [11:0] IMG_WIDTH [4:0] = {
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32
};
parameter [11:0] IMG_HEIGHT [4:0] = {
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32
};
module vm_init(
    // 总控制
    input ui_clk,
    input ui_clk_sync_rst,
    input init_start,
    output reg init_end,            //当加载结束后，会向外界持续输出高电平
    // SDRAM和SD卡向内输入的信息,
    input [7:0] sd_buffer[511:0],
    input sd_read_end,
    input cmd_done,
    //向外控制SD卡和SDRAM的信号 [TODO]外界需要进行信号的对接
    output sd_read_start,
    output [31:0] curr_sd_addr,
    output [1:0] sdram_cmd,
    output [29:0] curr_sdram_addr,
    output [63:0] sdram_buffer
);
    
    /******************  ImgLoader  ****************/
    reg load_start;
    reg load_end;
    reg last_load_end;
    reg [11:0] img_width;
    reg [11:0] img_height;
    reg [31:0] sd_start_addr;
    reg [29:0] sdram_start_addr;
    ///////////// 一定一定要检查信号宽度，2025.5.15日我因为loader_sdram_cmd误写成一位而被折磨了2个小时
    async_ImgLoader u_async_ImgLoader(
        //数据总信息
        // .debug_number(number),
        .ui_clk(ui_clk),       // 仍旧使用显存的时钟频率
        .ui_rst(ui_clk_sync_rst),
        .load_start(load_start),           //开始加载一个命令
        .load_end(load_end),        //图片加载结束，可以开始下一次加载
        .in_width(img_width),         
        .in_height(img_height),        // 最终读取的数据量为：img_width*img_height*3 bytes
        .sd_start_addr(sd_start_addr),    // SD卡图片的起始地址
        .sdram_start_addr(sdram_start_addr),  // SDRAM待写入的起始地址
        // .loader_info(number[31:8]),
        //SD
        .loader_sd_read_end(sd_read_end),
        .loader_sd_read_start(sd_read_start),
        .loader_curr_sd_addr(curr_sd_addr),
        .loader_sd_buffer(sd_buffer),      // 从sd卡读取的数据 [TODO]这种方法语法是否正确？
        //SDRAM
        .loader_sdram_write_end(cmd_done),
        .loader_sdram_cmd(sdram_cmd),           // SDRAM输出命令，这里仅仅使用2来写入
        .loader_curr_sdram_addr(curr_sdram_addr),      // SDRAM输出的地址
        .loader_sdram_buffer(sdram_buffer)          // 向SDRAM输出的数据
    );

    // 每一个加载

    /*************   显存仲裁器   ************/
    localparam [3:0] UNINIT=0 , LOAD=1, DONE = 2;
    localparam  [7:0] IMG_NUM = 5;    //
    reg [7:0] load_index;       //当前正在加载第几个图片
    reg [3:0]vm_init_stat;       //显存状态
    reg [1:0] done_delay_counter;         //用于最后延时释放load_done信号
    always @(posedge ui_clk)begin       //显存逻辑：使用sdram输出的时钟
        if(ui_clk_sync_rst)begin
            load_index <= 0;
            vm_init_stat <= UNINIT;
            load_start <= 1'b0;
            img_width <= 12'd32;
            img_height <= 12'd32;
            sd_start_addr <= 32'd0;
            sdram_start_addr <= 30'd0;
            last_load_end <= 1'b0;
            init_end <= 1'b0;
            done_delay_counter <= 2'b0;
        end else begin
            if(vm_init_stat == UNINIT)begin
                if(init_start)begin
                    vm_init_stat <= LOAD;        // SDRAM初始化完成，进入Load Sources状态
                end
            end else if(vm_init_stat == LOAD)begin
                img_width <= IMG_WIDTH[load_index];
                img_height <= IMG_HEIGHT[load_index];
                sd_start_addr <= IMG_INDEX[load_index] * 512;
                sdram_start_addr <= IMG_INDEX[load_index] * 512;
                load_start <= 1'b1;     //开始加载数据
                if( (~last_load_end) & load_end )begin
                    load_start <= 1'b0;
                    if(load_index == IMG_NUM-1)begin
                        vm_init_stat <= DONE;        // 加载完成，进入Done状态
                        init_end <= 1'b1;        
                        load_index <= 0;
                    end else begin
                        load_index <= load_index + 1;
                    end
                end
            end else begin      // DONE 加载完成
                init_end <= 1'b1;       // 因为该模块在加载后就没有用了，所以可以用最简单的通讯协议
            end
            last_load_end <= load_end;
        end
    end

endmodule