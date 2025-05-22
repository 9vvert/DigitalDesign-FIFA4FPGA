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
parameter OBJ_NUM = 2;
import type_declare::*;
module vm_manager
// 测试阶段，只绘制2个物体 
(
    output reg [31:0]debug_number,
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
    //数据，和game.sv对接 [TODO]
    input [11:0] y_pos[OBJ_NUM-1:0],           //用y值来判断渲染顺序
    input Render_Param_t in_render_param[OBJ_NUM-1:0],          //具体参数，用来表示渲染的位置，以及采用什么图片素材




    //和video.sv对接的信号
    input batch_free,       // 当RAM进行一轮交换后，会发送这个信号，并持续相当长一段周期，保证能够接受到
                            // 这个信号仅仅是用来切换到switcher
    //[TODO]检查和switch中的宽度是否一致，以及在空闲时候，switch输出的值是否会干扰正常逻辑
    output [31:0] write_data,   //[TODO]研究SRAM的字节序，注意进行顺序变换
    output [14:0] write_addr,   //每一个batch，write_addr都是从0开始逐渐增减，在video.sv中会再进行一轮变换
    output write_enable,        //写入显存的使能信号
    output out_ui_clk
);


    /*************   SD卡    *************/
    reg sd_read_start;
    reg sd_read_end;
    reg [31:0] sd_addr;
    reg [7:0] sd_buffer[511:0];
    sd_IO u_sd_IO(
        .clk_100m(clk_100m),
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
    // wire sdram_init_calib_complete; //检测到为高的时候，SDRAM正式进入可用状态
    // // Fake SDRAM model
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
    localparam TURN = TEST_DEBUG ? 9 : 45;   //每一帧进行45次交换
    reg [5:0] frame_counter; //和TURN一起使用
    localparam [3:0] START = 0, INIT = 1, RENDER = 3, SWITCH = 4, IDLE = 5, SORT=6, DONE=7, FINISH=8, TEST_SHOW=9;
    reg [3:0] manager_stat;  
    reg vm_flag;           //用于表示分区状态
    reg [1:0] sort_counter;      // 排序计数器，在第一个周期赋值
    reg have_sorted;      // 是否已经完成排序; 每次交换显存后，开始新的一帧，就需要进行重置
    reg [4:0] render_counter;     // 当前渲染了几个图形

    assign out_ui_clk = ui_clk;

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
    reg [4:0] index [0:31];   // 输出排序后的序号
    wire sort_done;                 // 排序完成信号
    reg last_sort_done;             // 捕捉上升沿
    // sort u_sort (
    //     // 大约需要4us完成排序，绰绰有余
    //     .clk(ui_clk),
    //     .rst(ui_rst),
    //     .start(sort_start),
    //     .data_in(data_in),
    //     .index(index),
    //     .done(sort_done)
    // );

    /****************  vm_renderer  ****************/
    reg draw_begin;
    wire draw_end;
    reg last_draw_end;
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
        .vm_renderer_ui_clk(ui_clk),
        .ui_rst(ui_rst),
        //和上层的接口
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

    /***************测试 ******************/
    reg[1:0] test_cmd;
    reg[29:0] test_addr;
    reg show_begin;
    test_load u_test_load(
        .ui_clk(ui_clk),
        .ui_rst(ui_rst),
        // 与SDRAM交互的信号
        .sdram_cmd(test_cmd),          //命令，  0无效，1读取，2写入
        .operate_addr(test_addr),      //地址
        .read_data(sdram_read_data),
        .cmd_done(cmd_done),
        //对外接口
        .show_begin(show_begin),
        .debug_number(debug_number)
    );

    /*****************  SRAM信号仲裁  *****************/
    assign sram_io_req= (manager_stat == SWITCH) ? switch_sram_io_req:
                        (manager_stat == RENDER) ? render_sram_io_req:
                        'bz;
    assign times =  (manager_stat == SWITCH) ? switch_sram_times:
                    (manager_stat == RENDER) ? render_sram_times:
                    'bz;
    assign addr =   (manager_stat == SWITCH) ? switch_sram_addr:
                    (manager_stat == RENDER) ? render_sram_addr:
                    'bz;
    assign wr = (manager_stat == SWITCH) ? switch_sram_wr:
                (manager_stat == RENDER) ? render_sram_wr:
                'bz;
    assign din = (manager_stat == RENDER) ? render_sram_din : 'bz;
    
    // 进行batch信号的同步
    reg batch_free1, batch_free2;       // 来自 hdmi_clk
    always @(posedge ui_clk)begin
        batch_free1 <= batch_free;
        batch_free2 <= batch_free1;
    end

    reg [7:0] f_counter;        // 帧计数器
    reg test_flag;
    always@(posedge ui_clk)begin
        if(ui_rst)begin
            //
            f_counter <= 0; //测试用
            test_flag <= 0;
            show_begin <= 0;
            //
            manager_stat <= IDLE;
            sort_counter <= 2'd0;
            have_sorted <= 1'b0;
            frame_counter <= 6'd0;
            vm_flag <= 1'b0;
            render_counter <= 0;
            //vm_init
            init_start <= 1'b0;
            index[31] <= 5'd0;
            index[30] <= 5'd1;
            //
            switch_begin <= 1'b0;

        end else begin
            case(manager_stat)
                START:begin
                    if(sdram_init_calib_complete)begin
                        manager_stat <= INIT;
                    end
                end
                INIT:begin
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
                    if(test_flag)begin
                        manager_stat <= TEST_SHOW;
                    end else if(batch_free2)begin
                        manager_stat <= SWITCH;
                    end
                end
                SORT:begin
                    // if(sort_counter == 2'd0)begin
                    //     for(int i=0; i<32; i=i+1)begin
                    //         if(i < OBJ_NUM)begin
                    //             data_in[i] <= y_pos[i];   // 这里需要进行数据的传递
                    //         end else begin
                    //             data_in[i] <= 12'd0;   // 这里需要进行数据的传递
                    //         end
                    //     end
                    //     sort_counter <= sort_counter + 2'd1;
                    // end else begin
                    //     sort_start <= 1'b1;
                    //     //[TODO]这里进行数据的初步处理
                    //     if(~last_sort_done & sort_done)begin
                    //         manager_stat <= DONE;
                    //         have_sorted <= 1'b1;    // 这一帧已经完成排序
                    //         sort_start <= 1'b0;
                    //     end
                    // end

                    //[TODO]测试阶段，暂时不加排序
                    index[31] <= 5'd0;
                    index[30] <= 5'd1;
                    have_sorted <= 1'b1;
                    manager_stat <= DONE;
                end
                RENDER:begin
                    // 绘制一个图形
                    // [TODO]修改参数
                    if(render_counter < 2)begin

                        draw_begin <= 1'b1;
                        
                        sdram_cmd <= render_sdram_cmd;
                        sdram_addr <= render_operate_addr;
                        sdram_write_data <= render_write_data;
                        // [TODO]这里进行数据的初步处理，并给render_param赋值
                        // 31是vpos最大的一个，这里应该从vpos小的图形开始渲染
                        render_param <= in_render_param[ index[32 - OBJ_NUM + render_counter] ];
                        if(~last_draw_end & draw_end)begin
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
                        if(have_sorted)begin        //这一帧排完序了就
                            manager_stat <= RENDER;
                        end else begin
                            manager_stat <= SORT;
                        end
                    end

                    // DEBUG： 跳过switch，检查是不是hdmi本身的问题
                end
                DONE:begin
                    // DONE代表一个周期
                    if(frame_counter == TURN - 1)begin
                        frame_counter <= 6'd0;      // 这会影响vm_switch中的地址计算 [TODO]检查
                        have_sorted <= 0;           //[TODO]检查有没有其它需要清零的变量
                        sort_counter <= 0;
                        render_counter <= 0;

                        ////////////////
                        if(f_counter == 250)begin
                            test_flag <= 1;
                        end else begin
                            f_counter <= f_counter + 1;
                        end
                        
                        vm_flag <= ~vm_flag;      //交换分区
                    end else begin
                        frame_counter <= frame_counter + 1;
                    end
                    manager_stat <= IDLE;
                end
                TEST_SHOW : begin
                    sdram_cmd <= test_cmd;
                    sdram_addr <= test_addr;
                    show_begin <= 1;
                end
            endcase
        end
        last_sort_done <= sort_done;
        last_draw_end <= draw_end;
        last_switch_end <= switch_end;
    end
endmodule