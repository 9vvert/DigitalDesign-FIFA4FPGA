// 负责将图片资源加载到SDRAM中，规划每一个显存资源的位置，定义描述符
// 负责规划SDRAM的总区域

// 每个图片描述符都是一个数字，代表着：该图片存放在SD卡的某个扇区中，而且乘以512就是SDRAM中的存放位置

parameter [19:0] IMG_INDEX [80:0] = {
    // 这里是background
    20'd10000,
    //
    20'd10, 20'd20, 20'd30, 20'd40, 20'd50,
    20'd110, 20'd120, 20'd130, 20'd140, 20'd150,
    20'd210, 20'd220, 20'd230, 20'd240, 20'd250,
    20'd310, 20'd320, 20'd330, 20'd340, 20'd350,
    20'd410, 20'd420, 20'd430, 20'd440, 20'd450,
    20'd510, 20'd520, 20'd530, 20'd540, 20'd550,
    20'd610, 20'd620, 20'd630, 20'd640, 20'd650,
    20'd710, 20'd720, 20'd730, 20'd740, 20'd750,
    20'd1010, 20'd1020, 20'd1030, 20'd1040, 20'd1050,
    20'd1110, 20'd1120, 20'd1130, 20'd1140, 20'd1150,
    20'd1210, 20'd1220, 20'd1230, 20'd1240, 20'd1250,
    20'd1310, 20'd1320, 20'd1330, 20'd1340, 20'd1350,
    20'd1410, 20'd1420, 20'd1430, 20'd1440, 20'd1450,
    20'd1510, 20'd1520, 20'd1530, 20'd1540, 20'd1550,
    20'd1610, 20'd1620, 20'd1630, 20'd1640, 20'd1650,
    20'd1710, 20'd1720, 20'd1730, 20'd1740, 20'd1750
    // ,20'd10000
};
parameter [11:0] IMG_WIDTH [80:0] = {
    // background
    12'd1280,
    //
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32
    // ,12'd1280
};
parameter [11:0] IMG_HEIGHT [80:0] = {
    //background
    12'd720,
    //
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32,
    12'd32, 12'd32, 12'd32, 12'd32, 12'd32
    // ,12'd720
};
module vm_init(
    // 总控制
    input vm_init_ui_clk,
    input vm_init_ui_rst,
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
        .imgloader_ui_clk(vm_init_ui_clk),       // 仍旧使用显存的时钟频率
        .ui_rst(vm_init_ui_rst),
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

    
    localparam [3:0] UNINIT=0 , LOAD=1, DONE = 2;
    localparam  [7:0] IMG_NUM = (TEST_DEBUG ? 1 : 81);    //
    reg [7:0] load_index;       //当前正在加载第几个图片
    reg [3:0]vm_init_stat;       //显存状态
    reg [1:0] done_delay_counter;         //用于最后延时释放load_done信号
    always @(posedge vm_init_ui_clk)begin       //显存逻辑：使用sdram输出的时钟
        if(vm_init_ui_rst)begin
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
                sd_start_addr <= { {12{1'b0}}, IMG_INDEX[load_index] } << 9;
                sdram_start_addr <= { {10{1'b0}}, IMG_INDEX[load_index] } << 9;
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