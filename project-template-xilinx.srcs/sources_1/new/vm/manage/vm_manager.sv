/*********  显存控制总模块  ********/
// 作用：负责显存的启动、交换，一边和渲染器对接，进行下一帧的绘画，一边向video.sv发送pixel batch；
// [TODO] 显存的启动：调用async_ImgLoader, 将SD卡中的数据加载到SDRAM中
// 接着

// 定义显存块1，显存块2，背景帧的起始位置
// 前16个MB留给素材
parameter KB = 1024;
parameter MB = 1024*KB;
// 这些BUF的开始位置不需要随着分辨率改变
// parameter BUF1_START = 16*MB, BUF2_START = 18*MB, BG_FRAME_START = 20*MB;
parameter BG_FRAME_START = 20*MB;
parameter OBJ_NUM = 1;
import type_declare::*;
module vm_manager
// 测试阶段，只绘制2个物体 
(
    output reg [15:0]debug_number,
    input clk_100m,       // 100MHz
    input rst,
    input clk_locked,     // 复位信号
    input clk_ddr,       // 400MHz
    input clk_ref,       // 200MHz
    //SD接口
    output wire        sd_sclk,     // SPI 时钟
    output wire        sd_mosi,     // 数据输出
    input  wire        sd_miso,     // 数据输入
    output wire        sd_cs,       // SPI 片选，低有效
    input  wire        sd_cd,       // 卡插入检测，0 表示有卡插入
    input  wire        sd_wp,       // 写保护检测，0 表示写保护状态
    //SDRAM接口
    inout  wire [7 :0] ddr3_dq,
    inout  wire [0 :0] ddr3_dqs_n,
    inout  wire [0 :0] ddr3_dqs_p,
    output wire [15:0] ddr3_addr,
    output wire [2 :0] ddr3_ba,
    output wire        ddr3_ras_n,
    output wire        ddr3_cas_n,
    output wire        ddr3_we_n,
    output wire        ddr3_reset_n,
    output wire [0 :0] ddr3_ck_p,
    output wire [0 :0] ddr3_ck_n,
    output wire [0 :0] ddr3_cke,
    output wire [0 :0] ddr3_cs_n,
    output wire [0 :0] ddr3_dm,
    output wire [0 :0] ddr3_odt,
    //SRAM接口
    inout  wire [31:0] base_ram_data,   // SRAM 数据
    output wire [19:0] base_ram_addr,   // SRAM 地址
    output wire [3: 0] base_ram_be_n,   // SRAM 字节使能，低有效。如果不使用字节使能，请保持为0
    output wire        base_ram_ce_n,   // SRAM 片选，低有效
    output wire        base_ram_oe_n,   // SRAM 读使能，低有效
    output wire        base_ram_we_n,   // SRAM 写使能，低有效
    //和中间层sprite_generator对接
    input Render_Param_t in_render_param[31:0],    // 实际上的OBJ_NUM < 32
    input [5:0] input_bg_index,
    input game_bg_change,
    output reg bg_change_done,
    //和video.sv对接的信号
    input batch_free,       // 当RAM进行一轮交换后，会发送这个信号，并持续相当长一段周期，保证能够接受到
    input batch_zero,       // 特殊标志，外部保证batch_zero和batch_free不会同时出现
    output reg dark_begin,
    output reg light_begin,
    input light_end,
    input dark_end,
    //[TODO]检查和switch中的宽度是否一致，以及在空闲时候，switch输出的值是否会干扰正常逻辑
    output [31:0] write_data,   //[TODO]研究SRAM的字节序，注意进行顺序变换
    output [14:0] write_addr,   //每一个batch，write_addr都是从0开始逐渐增减，在video.sv中会再进行一轮变换
    output write_enable,        //写入显存的使能信号
    output out_ui_clk,
    output out_ui_rst
);
    // /***********  SDRAM  ************/
    reg [2:0] sdram_controller_stat;    //
    wire ui_clk;                 // 由SDRAM输出
    wire ui_rst;
    reg [1:0]sdram_cmd;
    reg [29:0]sdram_addr;
    reg [63:0]sdram_write_data;
    reg [63:0]sdram_read_data;
    reg cmd_done;
    wire sdram_init_calib_complete; //检测到为高的时候，SDRAM正式进入可用状态
    sdram_IO u_sdram_IO(
        .ui_clk(ui_clk),
        .ui_clk_sync_rst(ui_rst),
        .init_calib_complete(sdram_init_calib_complete),
        .ddr3_dq(ddr3_dq),
        .ddr3_dqs_n(ddr3_dqs_n),
        .ddr3_dqs_p(ddr3_dqs_p),
        .ddr3_addr(ddr3_addr),
        .ddr3_ba(ddr3_ba),
        .ddr3_ras_n(ddr3_ras_n),
        .ddr3_cas_n(ddr3_cas_n),
        .ddr3_we_n(ddr3_we_n),
        .ddr3_reset_n(ddr3_reset_n),
        .ddr3_ck_p(ddr3_ck_p),
        .ddr3_ck_n(ddr3_ck_n),
        .ddr3_cke(ddr3_cke),
        .ddr3_cs_n(ddr3_cs_n),
        .ddr3_dm(ddr3_dm),
        .ddr3_odt(ddr3_odt),

        .sys_clk_i(clk_ddr),  // 400MHz
        .clk_ref_i(clk_ref),  // 200MHz
        .sys_rst(!clk_locked),

        // .sdram_info(number[7:0]),
        //对外接口
        .sdram_cmd(sdram_cmd),          //命令，  0无效，1读取，2写入
        .operate_addr(sdram_addr),      //地址
        .write_data(sdram_write_data),
        .read_data(sdram_read_data),
        .cmd_done(cmd_done)             //这一轮命令结束
    );

    /*************   SD卡    *************/
    reg sd_read_start;
    reg sd_read_end;
    reg [31:0] sd_addr;
    reg [7:0] sd_buffer[511:0];
    sd_IO u_sd_IO(
        .ui_clk(ui_clk),
        .rst(~clk_locked),
        // SD 卡（SPI 模式）
        .sd_sclk(sd_sclk),     // SPI 时钟
        .sd_mosi(sd_mosi),     // 数据输出
        .sd_miso(sd_miso),     // 数据输入
        .sd_cs(sd_cs),       // SPI 片选，低有效
        .sd_cd(sd_cd),       // 卡插入检测，0 表示有卡插入
        .sd_wp(sd_wp),       // 写保护检测，0 表示写保护状态
        //对外接口
        .read_start(sd_read_start),               // 因为SD卡频率较慢，外界必须等待一段时间才能将raed_start降低
        .read_end(sd_read_end),                // 加载完成
        .sd_src_addr(sd_addr),       // SD卡
        .mem(sd_buffer)
    );

    // /*****************  模拟SD卡和SDRAM   *****************/
    // /**************  模拟SD卡 **************/
    // reg sd_read_start;
    // reg sd_read_end;
    // reg [31:0] sd_addr;
    // reg [7:0] sd_buffer[511:0];
    // // Fake SD card model
    // fake_sd u_fake_sd (
    //     .clk_100m (clk_100m),
    //     .rst (rst),
    //     .read_start (sd_read_start),
    //     .read_end (sd_read_end),
    //     .sd_src_addr (sd_addr),
    //     .mem (sd_buffer)
    // );
    // // /**************  模拟SDRAM **************/
    // wire ui_clk;                 // 由SDRAM输出
    // wire ui_rst;
    // reg [1:0]sdram_cmd;
    // reg [29:0]sdram_addr;
    // reg [63:0]sdram_write_data;
    // reg [63:0]sdram_read_data;
    // reg cmd_done;
    // fake_sdram u_fake_sdram (
    //     .clk_100m(clk_100m),
    //     .ui_clk(ui_clk),
    //     .ui_clk_sync_rst(ui_rst),
    //     .init_calib_complete(sdram_init_calib_complete),
    //     .sdram_cmd(sdram_cmd),
    //     .operate_addr(sdram_addr),
    //     .write_data(sdram_write_data),
    //     .read_data(sdram_read_data),
    //     .cmd_done(cmd_done)
    // );

    /****************   SRAM   *****************/

    wire sram_io_req;        //读写请求
    wire [19:0] times;       //读写次数
    wire wr;                 //是否选择“写”
    wire [19:0] addr;        
    wire [31:0] din;    //switch 用不到din
    wire [31:0] dout;

    sram_IO u_sram_IO(
        .clk(ui_clk),       // 100MHz
        .rst(ui_rst),
        .req(sram_io_req),
        .times(times),
        .addr(addr),
        .wr(wr),
        .din(din),
        .dout(dout),
        .base_ram_data(base_ram_data),
        .base_ram_addr(base_ram_addr),
        .base_ram_be_n(base_ram_be_n),
        .base_ram_ce_n(base_ram_ce_n),
        .base_ram_oe_n(base_ram_oe_n),
        .base_ram_we_n(base_ram_we_n)
    );

    /*************   manager FSM  **************/
    // [change]
    localparam TURN = 60;   //每一帧进行90次交换，这样能够绘画的图形会翻倍
    reg [6:0] frame_counter; //和TURN一起使用
    localparam [3:0] START = 0, INIT = 1, RENDER = 3 ,SWITCH = 4, IDLE = 5, SORT=6, DONE=7, FINISH=8,
        TEST_SHOW=9, SWITCH_BG=10, SWITCH_BG_DELAY=11, FILL = 12, PRE_SORT=13, PRE_RENDER=14;       
    reg [3:0] manager_stat;  
    reg vm_flag;           //用于表示分区状态
    reg [1:0] sort_counter;      // 排序计数器，在第一个周期赋值
    reg have_sorted;      // 是否已经完成排序; 每次交换显存后，开始新的一帧，就需要进行重置
    reg [5:0] render_counter;     // 当前渲染了几个图形
    reg [5:0] fill_counter;         // 当前填补了几块背景
    reg switch_bg_flag;
    reg new_frame;          // 用于batch同步。当该信号为高的时候，下一次下一次必须接受
    Render_Param_t render_param_buffer[31:0];           // 保证同一个周期中使用的是一个

    assign out_ui_clk = ui_clk;
    assign out_ui_rst = ui_rst;
    /****************  vm_init  ****************/
    reg init_start;
    wire init_end;
    wire init_sd_read_start;
    wire [31:0] init_curr_sd_addr;
    wire [1:0] init_sdram_cmd;       
    wire [29:0] init_curr_sdram_addr;
    wire [63:0] init_sdram_buffer;
    vm_init u_vm_init(
        // 总控制
        .vm_init_ui_clk(ui_clk),
        .vm_init_ui_rst(ui_rst),
        .init_start(init_start),
        .init_end(init_end),
        // SDRAM和SD卡向内输入的信息
        // [TODO]需要再确认这里一直赋值会不会有问题
        .sd_buffer(sd_buffer),
        .sd_read_end(sd_read_end),
        .cmd_done(cmd_done),
        //向外控制SD卡和SDRAM的信号 [TODO]外界需要进行信号的对接
        .sd_read_start(init_sd_read_start),
        .curr_sd_addr(init_curr_sd_addr),
        .sdram_cmd(init_sdram_cmd),          //命令，  0无效，1读取，2写入
        .curr_sdram_addr(init_curr_sdram_addr),
        .sdram_buffer(init_sdram_buffer)          // 向SDRAM输出的数据
    );
    // RENDER和SWITCH交替进行，各自执行45次。最多能提供22个图形的渲染(因为填补背景也会消耗一次，因此实际开销是2倍)

    /****************  vm_switch  ****************/
    reg switch_begin;
    wire switch_end;
    reg last_switch_end;    //捕捉上升沿
    // SRAM接口
    wire switch_sram_io_req;
    wire [19:0] switch_sram_times;
    wire switch_sram_wr;
    wire [19:0] switch_sram_addr;
    vm_switch u_vm_switch(
        .vm_switch_ui_clk(ui_clk),
        .ui_rst(ui_rst),
        //和上层的接口
        .vm_flag(vm_flag),           //负责交换分区; 0代表用BUF2，1代表用BUF1
        .switch_begin(switch_begin),             // 开始新一轮的交换（上层的vm_manager.sv需要严格控制交换次数）
        .switch_end(switch_end),         //本轮的batch交换完成
        .frame_counter(frame_counter),  //和上层的交换次数对接
        //与SRAM的接口
        .sram_io_req(switch_sram_io_req),            // 读写请求，在req为高的时候读取wr，
        .times(switch_sram_times),     // 连续执行多少次操作
        .wr(switch_sram_wr),             // 1:写, 0:读
        .addr(switch_sram_addr),           // 20位地址        //需要及时更新
        .dout(dout),           // 读出数据
        //与video的接口
        .write_data(write_data),   //[TODO]研究SRAM的字节序，注意进行顺序变换
        .write_addr(write_addr),   //每一个batch，write_addr都是从0开始逐渐增减，在video.sv中会再进行一轮变换
        .write_enable(write_enable)
    );
    /***************   sort ************************/
    reg sort_start;
    reg [11:0] data_in [0:31]; // 输入数据
    wire [4:0] index [0:31];   // 输出排序后的序号
    wire sort_done;                 // 排序完成信号
    reg last_sort_done;             // 捕捉上升沿
    sort u_sort (
        .clk(ui_clk),
        .rst(ui_rst),
        .start(sort_start),
        .data_in(data_in),
        .index(index),
        .done(sort_done)
    );

    /****************  vm_renderer  ****************/
    reg draw_begin;
    wire draw_end;
    reg last_draw_end;
    reg [5:0] tmp_bg;
    reg render_type;
    Render_Param_t bg_square [31:0];     //用于存放下一帧需要覆盖的背景
    Render_Param_t bg_square1 [31:0];
    // sdram， 素材
    wire [1:0] render_sdram_cmd;
    wire [29:0] render_operate_addr;
    wire [63:0] render_write_data;
    Render_Param_t render_param;   // 物体的参数
    // sram 参数
    wire render_sram_io_req;
    wire [19:0] render_sram_times;
    wire render_sram_wr;
    wire [19:0] render_sram_addr;
    wire [31:0] render_sram_din;
    vm_renderer u_vm_renderer(
        // .debug_number(debug_number),
        .vm_renderer_ui_clk(ui_clk),
        .ui_rst(ui_rst),
        //和上层的接口
        .bg_index(tmp_bg),
        .render_type(render_type),
        .vm_flag(vm_flag),         //负责交换分区; 0代表用BUF2，1代表用BUF1
        .draw_begin(draw_begin),         
        .draw_end(draw_end),
        .render_param(render_param),   // 物体的参数
        // 与SDRAM交互的信号
        .sdram_cmd(render_sdram_cmd),          //命令，  0无效，1读取，2写入
        .operate_addr(render_operate_addr),      //地址
        .write_data(render_write_data),
        //[TODO]再次检查：一直到最深处，持续的给cmd_done和read_data赋值会不会有问题
        .read_data(sdram_read_data),
        .cmd_done(cmd_done),
        // 与SRAM交互的信号
        .sram_io_req(render_sram_io_req),
        .times(render_sram_times),
        .wr(render_sram_wr),
        .addr(render_sram_addr),
        .din(render_sram_din),
        .dout(dout)
    );


    /*************  背景切换器  **************/
    reg switch_bg_begin;
    reg [5:0] switch_bg_index;      //背景切换器使用的内容
    wire switch_bg_end;
    reg last_switch_bg_end;
    reg copy_done;          // 这个信号由亮度由亮度控制器监测，当为1的时候，开始进入LIGHT模式
    reg [1:0] bg_delay_counter;     // 延时释放copy_done，否则过快进入IDLE会导致进入新一次COPY
    //sdram
    wire [1:0] bg_sdram_cmd;
    wire [29:0] bg_sdram_addr;
    //sram
    wire bg_sram_io_req;
    wire [19:0] bg_sram_times;
    wire bg_sram_wr;
    wire [19:0] bg_sram_addr;
    wire [31:0] bg_sram_din;
    switch_bg u_switch_bg(
        .switch_bg_ui_clk(ui_clk),
        .ui_rst(ui_rst),
        // 和game controller交互
        .switch_begin(switch_bg_begin),
        .bg_index(switch_bg_index),       // 使用的场景编号，应该也有一个映射
        .switch_end(switch_bg_end),
        // 与SDRAM交互的信号
        .sdram_cmd(bg_sdram_cmd),          //命令，  0无效，1读取，2写入
        .operate_addr(bg_sdram_addr),      //地址
        .read_data(sdram_read_data),
        .cmd_done(cmd_done),
        //与SRAM的接口
        .sram_io_req(bg_sram_io_req),
        .times(bg_sram_times),
        .wr(bg_sram_wr),
        .addr(bg_sram_addr),
        .din(bg_sram_din)
    );

    // /***************测试 ******************/
    // reg[1:0] test_cmd;
    // reg[29:0] test_addr;
    // reg show_begin;
    // test_load u_test_load(
    //     .ui_clk(ui_clk),
    //     .ui_rst(ui_rst),
    //     // 与SDRAM交互的信号
    //     .sdram_cmd(test_cmd),          //命令，  0无效，1读取，2写入
    //     .operate_addr(test_addr),      //地址
    //     .read_data(sdram_read_data),
    //     .cmd_done(cmd_done),
    //     //对外接口
    //     .show_begin(show_begin),
    //     .debug_number(debug_number)
    // );

    /*****************  SRAM信号仲裁  *****************/
    assign sram_io_req= (manager_stat == SWITCH) ? switch_sram_io_req:
                        (manager_stat == RENDER) ? render_sram_io_req:
                        (manager_stat == FILL) ? render_sram_io_req:
                        (manager_stat == SWITCH_BG) ? bg_sram_io_req:
                        'bz;
    assign times =  (manager_stat == SWITCH) ? switch_sram_times:
                    (manager_stat == RENDER) ? render_sram_times:
                    (manager_stat == FILL) ? render_sram_times:
                    (manager_stat == SWITCH_BG) ? bg_sram_times:
                    'bz;
    assign addr =   (manager_stat == SWITCH) ? switch_sram_addr:
                    (manager_stat == RENDER) ? render_sram_addr:
                    (manager_stat == FILL) ? render_sram_addr:
                    (manager_stat == SWITCH_BG) ? bg_sram_addr:
                    'bz;
    assign wr = (manager_stat == SWITCH) ? switch_sram_wr:
                (manager_stat == RENDER) ? render_sram_wr:
                (manager_stat == FILL) ? render_sram_wr:
                (manager_stat == SWITCH_BG) ? bg_sram_wr:
                'bz;
    assign din = (manager_stat == RENDER) ? render_sram_din : 
                (manager_stat == FILL) ? render_sram_din : 
                (manager_stat == SWITCH_BG) ? bg_sram_din :
                'bz;
    
    // 进行batch信号的同步
    reg batch_free1, batch_free2;       // 来自 hdmi_clk
    reg batch_zero1, batch_zero2;
    always @(posedge ui_clk)begin
        batch_free1 <= batch_free;
        batch_free2 <= batch_free1;
        batch_zero1 <= batch_zero;
        batch_zero2 <= batch_zero1;
    end

    // reg [7:0] f_counter;        // 帧计数器
    // reg test_flag;

    always@(posedge ui_clk)begin
        if(ui_rst)begin
            //
            // f_counter <= 0; //测试用
            // test_flag <= 0;
            // show_begin <= 0;
            //
            new_frame <= 1;             // 每次重新启动的时候，都需要设置new_fram = 1来实现同步
            manager_stat <= START;
            sort_counter <= 2'd0;
            have_sorted <= 1'b0;
            frame_counter <= 7'd0;
            vm_flag <= 1'b0;
            render_counter <= 0;
            fill_counter <= 0;
            //vm_init
            init_start <= 1'b0;
            //
            switch_begin <= 1'b0;
            // bg
            copy_done <= 0;
            bg_delay_counter <= 0;

            debug_number <= 0;
            // bg_square
            for(integer k=0; k<32; k=k+1)begin
                bg_square[k].enable <= 0;
                bg_square[k].hpos <= 128;
                bg_square[k].vpos <= 128;
            end

        end else begin
            case(manager_stat)
                START:begin
                    if(sdram_init_calib_complete)begin
                        // manager_stat <= IDLE;
                        manager_stat <= TEST_DEBUG ? IDLE : INIT;
                    end
                end
                INIT:begin
                    init_start <= 1;
                    sd_read_start <= init_sd_read_start;
                    sd_addr <= init_curr_sd_addr;
                    sdram_cmd <= init_sdram_cmd;
                    sdram_addr <= init_curr_sdram_addr;
                    sdram_write_data <= init_sdram_buffer;
                    //资源装载
                    //[TODO]这里进行信号的分配，将SDRAM_IO和vm_init连接起来

                    if(init_end)begin
                        sd_read_start <= 1'b0;  //信号归位
                        sdram_cmd <= 2'd0;
                        manager_stat <= IDLE;
                    end
                end
                IDLE:begin
                    // 这里时刻监听，当接收到video.sv发送的batch_free信号时，进行交换
                    // [TODO]后续进行检查，看这里应该捕捉上升沿还是持续检测
                    if(switch_bg_flag)begin
                        //当switch_bg_flag为1的时候，IDLE状态不再开启新的帧，而是进入复制状态
                        manager_stat <= SWITCH_BG;
                        new_frame <= 1;     // 下次对接的时候，需要重新同步
                    end else begin
                        if(new_frame)begin                  // 重新连接，因此需要一次同步，仅仅接受batch_zero信号
                            // [TODO]为了方便测试，这里宽松一些
                            if(batch_zero2 || (TEST_DEBUG&batch_free2))begin
                                new_frame <= 0;         // 关闭new_fram信号
                                //[TODO]重置一些变量
                                have_sorted <= 0;
                                sort_counter <= 0;
                                frame_counter <= 0;
                                vm_flag <= 0;
                                render_counter <= 0;
                                manager_stat <= SWITCH;
                            end
                        end else begin
                            if(batch_free2 | batch_zero2)begin  // 接受两者中的任意一个信号
                                manager_stat <= SWITCH;
                            end
                        end
                    end
                end
                PRE_SORT:begin
                    for(integer k=0; k<32; k=k+1)begin
                        render_param_buffer[k] <= in_render_param[k];
                    end
                    manager_stat <= SORT;
                end
                SORT:begin
                    if(sort_counter == 2'd0)begin
                        for(int i=0; i<32; i=i+1)begin
                            data_in[i] <= render_param_buffer[i].render_priority;
                        end
                        sort_counter <= sort_counter + 2'd1;
                    end else begin
                        sort_start <= 1'b1;
                        //[TODO]这里进行数据的初步处理
                        if(~last_sort_done & sort_done)begin
                            manager_stat <= DONE;
                            have_sorted <= 1'b1;    // 这一帧已经完成排序
                            sort_start <= 1'b0;
                        end
                    end
                end
                FILL:begin
                    //[TODO] 重要：外部需要确保enable=0的优先级为0，排在最后面
                    draw_begin <= 1'b1;
                    render_type <= 1;   //背景填补
                    sdram_cmd <= render_sdram_cmd;
                    sdram_addr <= render_operate_addr;
                    sdram_write_data <= render_write_data;
                    //  index[0]的优先级最高
                    render_param <= bg_square1[ fill_counter ];
                    
                    if(~last_draw_end & draw_end)begin
                        fill_counter <= fill_counter + 1;
                        draw_begin <= 1'b0;
                        manager_stat <= DONE;
                    end
                end
                RENDER:begin
                    // 绘制一个图形
                    // [TODO]修改参数
                    if(render_counter < OBJ_NUM)begin
                        draw_begin <= 1'b1;
                        render_type <= 0;   //图形绘制
                        sdram_cmd <= render_sdram_cmd;
                        sdram_addr <= render_operate_addr;
                        sdram_write_data <= render_write_data;
                        // [TODO]这里进行数据的初步处理，并给render_param赋值
                        // 31是vpos最大的一个，这里应该从vpos小的图形开始渲染
                        //[TODO] 这里会不会因为继承enable属性导致渲染错误？
                        render_param <= render_param_buffer[ index[render_counter] ];
                        debug_number[15:8] <= render_param_buffer[ index[render_counter] ].hpos[7:0];
                        debug_number[7:0] <= render_param_buffer[ index[render_counter] ].vpos[7:0];
                        // [TODO]在这里，将当前的渲染参数（只用坐标）赋给bg_square,供下一帧使用
                        if(~last_draw_end & draw_end)begin
                            //[TODO]不能写在外面，否则会执行多次
                            bg_square[ render_counter ] <= render_param_buffer[ index[render_counter] ];
                            bg_square1[ render_counter ] <= bg_square[ render_counter ];
                            render_counter <= render_counter + 1;
                            draw_begin <= 1'b0;
                            manager_stat <= DONE;
                        end
                    end else begin
                        manager_stat <= DONE;       //已经绘制完毕，直接进入IDLE状态
                    end
                    // DEBUG : 跳过RENDER，看是否还会花屏。如果是，那么很可能是交换的问题
                end
                SWITCH:begin
                    switch_begin <= 1'b1;
                    
                    if(~last_switch_end & switch_end)begin
                        switch_begin <= 1'b0;
                        //[TODO]更新：因为要填补的顺序是按照上一帧的index决定的，所以必须先进行fill再sort
                        if(fill_counter < OBJ_NUM)begin
                            manager_stat <= FILL;
                        end else if(!have_sorted)begin
                            manager_stat <= PRE_SORT;
                        end else begin
                            manager_stat <= RENDER;
                        end
                    end

                    // DEBUG： 跳过switch，检查是不是hdmi本身的问题
                end
                DONE:begin
                    // DONE代表一个周期
                    if(frame_counter == TURN - 1)begin
                        frame_counter <= 7'd0;      // 这会影响vm_switch中的地址计算 [TODO]检查
                        have_sorted <= 0;           //[TODO]检查有没有其它需要清零的变量
                        sort_counter <= 0;
                        render_counter <= 0;
                        fill_counter <= 0;
                        vm_flag <= ~vm_flag;      //交换分区
                    end else begin
                        frame_counter <= frame_counter + 1;
                    end
                    manager_stat <= IDLE;
                end
                SWITCH_BG: begin
                    sdram_cmd <= bg_sdram_cmd;
                    sdram_addr <= bg_sdram_addr;
                    switch_bg_index <= input_bg_index;   //[TODO]后续这里对接具体的数据
                    tmp_bg <= input_bg_index;        //供vm_renderer使用
                    switch_bg_begin <= 1;
                    if(~last_switch_bg_end & switch_bg_end)begin
                        copy_done <= 1;
                        switch_bg_begin <= 0;
                        manager_stat <= SWITCH_BG_DELAY;
                    end
                end
                SWITCH_BG_DELAY:begin
                    if(bg_delay_counter <= 2)begin
                        bg_delay_counter <= bg_delay_counter + 1;
                    end else begin
                        bg_delay_counter <= 0;
                        copy_done <= 0;
                        manager_stat <= IDLE;
                    end
                end
            endcase
        end
        last_sort_done <= sort_done;
        last_draw_end <= draw_end;
        last_switch_end <= switch_end;
        last_switch_bg_end <= switch_bg_end;
    end

    
    /********  场景亮度控制器  *********/
    localparam [2:0] LIGHT_WAIT=0, LIGHT=1, DARK=2, DARK_WAIT=3;
    reg [2:0] lc_stat;
    reg dark_end1,dark_end2,light_end1,light_end2;
    always@(posedge ui_clk)begin
        //信号同步
        dark_end1 <= dark_end;
        dark_end2 <= dark_end1;
        light_end1 <= light_end;
        light_end2 <= light_end1;
        //[TODO]后续这里应该同步game_clk的信号
        if(ui_rst)begin
            lc_stat <= LIGHT_WAIT;
            switch_bg_flag <= 0;
            bg_change_done <= 0;        //向外部输出的信号，表示是否完成切换
        end else begin
            if(lc_stat == LIGHT_WAIT)begin
                //[TODO]后续需要将这个信号进行同步
                bg_change_done <= 0;    //复位
                if(game_bg_change)begin
                    lc_stat <= DARK;
                end
            end else if(lc_stat == LIGHT)begin
                light_begin <= 1;
                if(light_end2)begin
                    //亮度已经恢复正常
                    light_begin <= 0;
                    lc_stat <= LIGHT_WAIT;
                end
            end else if(lc_stat == DARK)begin  // DARK
                dark_begin <= 1;
                if(dark_end2)begin
                    //等屏幕完全变暗后
                    switch_bg_flag <= 1;
                    lc_stat <= DARK_WAIT;
                end
            end else begin
                if(copy_done)begin
                    bg_change_done <= 1;
                    switch_bg_flag <= 0;    // 在下一次IDLE到来之前，及时将switch_bg_flag置为0，让其恢复正常
                    dark_begin <= 0;        // 必须及时将dark_begin拉低，否则会一直覆盖light_begin信号
                    lc_stat <= LIGHT;
                end
            end
        end
    end
endmodule