// 用于检验渲染
// 关于SDRAM的接口，使用“模拟”的方法

`timescale 1ns/1ps
module render_tb();

    reg clk;
    reg rst;

    reg mode;  //
    reg render_begin;
    reg render_end;

    reg [29:0] vm_start;
    reg [11:0] half_img_width;
    reg [11:0] half_img_height;
    reg [11:0] hpos;
    reg [11:0] vpos;
    reg [29:0] sprite_addr;    // 图片数据存放的地址（线性存储）
    // mode = 1 时， 下列有效
    reg [29:0] vm_background_start;   //背景在显存中另外开辟一个区域，和显存等大
    reg [11:0] bg_hpos;
    reg [11:0] bg_vpos;
    //控制SDRAM
    reg [1:0] sdram_cmd;          //命令，  0无效，1读取，2写入
    reg [29:0] operate_addr;      //地址
    reg [63:0] write_data;
    reg [63:0] read_data;
    reg cmd_done;   

    // sdram模拟模块
    fake_sdram u_fake_sdram(
        .clk(clk),
        .rst(rst),
        .sdram_cmd(sdram_cmd),       // 0无效，1读，2写
        .operate_addr(operate_addr),    // 忽略
        .write_data(write_data),      // 忽略
        .read_data(read_data),  // 忽略
        .cmd_done(cmd_done)
    );


    sprite_render u_sprite_render
    (
        //控制参数
        .ui_clk(clk),
        .ui_rst(rst),
        .mode(mode),     // 0:将线性存储的数据渲染到显存的指定坐标；  1：将背景的某一块补全
                        // 计划：第一次将背景加载到一块和显存等大的地方，此后就从这里来“复制”一块，进行填补
        .render_begin(render_begin),
        .render_end(render_end),
        //
        .vm_start(vm_start),      // 该显存开始的地址
        .half_img_width(half_img_width),    //[TODO]一定要注意：这里用半宽
        .half_img_height(half_img_height),
        .hpos(hpos),          // 物体在显存中渲染的坐标
        .vpos(vpos),
        // mode = 0 时， sprite_addr有效
        .sprite_addr(sprite_addr),    // 图片数据存放的地址（线性存储）
        // mode = 1 时， 下列有效
        .vm_background_start(vm_background_start),   //背景在显存中另外开辟一个区域，和显存等大
        .bg_hpos(bg_hpos),
        .bg_vpos(bg_vpos),
        //控制SDRAM
        .sdram_cmd(sdram_cmd),          //命令，  0无效，1读取，2写入
        .operate_addr(operate_addr),      //地址
        .write_data(write_data),
        .read_data(read_data),
        .cmd_done(cmd_done)   
    );

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, render_tb);       // 递归显示波形
        clk = 1'b0;
        rst = 1'b0;

        #100;
        rst = 1'b1;

        #100;
        rst = 1'b0;

        #100;
        render_begin <= 1;
        #50000;
        $finish;
    end

    reg [2:0] test_stat;
    localparam [2:0] M0=0, M1=1;
    always #5 clk = ~clk; // 100MHz

    reg last_render_end;
    always@(posedge clk)begin
        if(rst)begin
            test_stat <= M0;
            last_render_end <= 0;
        end else begin
            if(test_stat == M0)begin        // 轮流进入Mode1和Mode2
                mode <= 0;
                // render_begin <= 1'b1;
                vm_start <= 'd1024;
                half_img_height <= 16;
                half_img_width <= 16;
                hpos <= 100;
                vpos <= 100;
                sprite_addr <= 102400;
                if(~last_render_end & render_end)begin
                    test_stat <= M1;
                end
            end else begin
                mode <= 1;
                // render_begin <= 1'b1;
                vm_start <= 'd1024;
                half_img_height <= 16;
                half_img_width <= 16;
                hpos <= 100;
                vpos <= 100;
                vm_background_start <= 102400;
                bg_hpos <= 200;
                bg_vpos <= 200;
                if(~last_render_end & render_end)begin
                    test_stat <= M0;
                end
            end
            last_render_end <= render_end;
        end
    end

endmodule