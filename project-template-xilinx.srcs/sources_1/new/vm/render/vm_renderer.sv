/***********  vm_renderer  ***********/
// 根据三元组<上一时刻的位置， 这一时刻的位置， 素材编号>，建立一个渲染任务序列
// 渲染优先级：所有背景剪切优先级都最高，然后是辅助层（顺序无所谓），最后是按照y值进行排序的物体(外界将x,y,z进行变换，这里仅仅输入渲染的位置)
import type_declare::*;   

module vm_renderer
#(parameter VM_WIDTH = TEST_DEBUG ? TEST_HSIZE : 1280, VM_HEIGHT = TEST_DEBUG ? TEST_VSIZE : 720)
(
    input vm_renderer_ui_clk,
    input ui_rst,
    //和上层的接口
    input vm_flag,         //负责交换分区; 0代表用BUF2，1代表用BUF1
    input draw_begin,         
    output reg draw_end,
    input Render_Param_t render_param,
    // 与SDRAM交互的信号
    output reg[1:0] sdram_cmd,          //命令，  0无效，1读取，2写入
    output reg[29:0] operate_addr,      //地址
    output reg[63:0] write_data,
    input [63:0] read_data,
    input cmd_done,
    //与SRAM的接口
    output sram_io_req,        //读写请求
    output [19:0] times,       //读写次数
    output wr,                 //是否选择“写”
    output [19:0] addr,
    output [31:0] din,          // 渲染信息
    input [31:0] dout
);
    // 总控制
    reg last_cmd_done;
    reg [3:0] render_stat;  //渲染器状态
    localparam [3:0] IDLE=0, LOAD_LINE=1, RENDER_LINE=2, DONE=3;
    reg [5:0] line_counter;         //按照行来渲染
    reg [3:0] read_sdram_counter;   //每一行64字节需要8次读取
    reg [1:0] done_delay_counter;
    reg [15:0] line_buffer [31:0];   //一整行的像素数据
    reg [11:0] hpos;
    reg [11:0] vpos;            // 注意：和start_hpos, start_vpos不同， hpos和vpos是每一行第一个像素的起始地址

    /*************  资源映射器  ***************/
    //根据render_param，找到在SDRAM中的地址，并且根据类型计算出渲染的起始h_pos和v_pos
    //[TODO]后续
    logic [2:0] direction;  // 计算出的方向值
    logic [7:0] angle;
    logic [2:0] render_type;
    logic [3:0] stat;
    logic [29:0] result_addr;
    logic [11:0] start_hpos;          // 渲染目标左上角的坐标
    logic [11:0] start_vpos;
    
    assign angle = render_param.angle;
    assign stat = render_param.stat;
    assign render_type = render_param.render_type;
    always_comb begin
        // 根据type，计算出h_pos和y_pos
        // [TODO]后续需要修改这里的逻辑
        if(render_type <= 2)begin
            start_hpos = render_param.hpos-16;
            start_vpos = render_param.vpos-32;
        end else begin
            start_hpos = render_param.hpos;
            start_vpos = render_param.vpos;
        end
        // 计算方向值
        if (angle >= 68 || angle <= 4)
            direction = 3'd0;
        else if (angle >= 5 && angle <= 13)
            direction = 3'd1;
        else if (angle >= 14 && angle <= 22)
            direction = 3'd2;
        else if (angle >= 23 && angle <= 31)
            direction = 3'd3;
        else if (angle >= 32 && angle <= 40)
            direction = 3'd4;
        else if (angle >= 41 && angle <= 49)
            direction = 3'd5;
        else if (angle >= 50 && angle <= 58)
            direction = 3'd6;
        else if (angle >= 59 && angle <= 67)
            direction = 3'd7;
        else
            direction = 3'd0; // 默认值
        result_addr = ((direction * 100) + (stat * 10)) * 512;
    end

    /***********  渲染引擎   ***********/
    reg render_begin;
    wire render_end;
    reg last_render_end;      //捕捉上升沿
    // 行渲染器
    line_render u_line_render(
        .line_render_ui_clk(vm_renderer_ui_clk),
        .ui_rst(ui_rst),
        .vm_flag(vm_flag),
        .render_begin(render_begin),
        .render_end(render_end),
        .hpos(hpos),          // 这一行第一个像素的坐标
        .vpos(vpos),
        .line_buffer(line_buffer),
        //控制SRAM
        .sram_io_req(sram_io_req),
        .wr(wr),
        .times(times),
        .addr(addr),
        .din(din),
        .dout(dout)
    );

    /***********  渲染状态机  ***********/
    always @(posedge vm_renderer_ui_clk)begin
        if(ui_rst)begin
            done_delay_counter <= 1'b0;
            render_stat <= IDLE;
            last_render_end <= 1'b0;
            last_cmd_done <= 0;
        end else begin
            if(render_stat == IDLE)begin
                if(draw_begin)begin
                    render_stat <= LOAD_LINE;   // 先读取一行的数据
                    //[TODO]后续要加上背景取样的逻辑，那么这里的img_part_addr需要进行判断、分类计数

                    // LOAD参数初始化
                    operate_addr <= result_addr;   // 初始：赋值为图片资源开始的地方
                    line_counter <= 0;
                    read_sdram_counter <= 0;
                    // RENDER参数初始化
                    hpos <= start_hpos;
                    vpos <= start_vpos;
                end
            end else if(render_stat == LOAD_LINE)begin
                sdram_cmd <= 1;     // 读取
                if(~last_cmd_done & cmd_done)begin
                    //[TODO]这里的顺序是否正确？
                    line_buffer[4*read_sdram_counter] <= read_data[63:48];
                    line_buffer[4*read_sdram_counter+1] <= read_data[47:32];
                    line_buffer[4*read_sdram_counter+2] <= read_data[31:16];
                    line_buffer[4*read_sdram_counter+3] <= read_data[15:0];
                    if(read_sdram_counter == 7)begin
                        //行数据读取完毕
                        sdram_cmd <= 0;              // 结束数据读取
                        read_sdram_counter <= 0;
                        render_stat <= RENDER_LINE;
                    end else begin
                        //保持sdram_cmd
                        operate_addr <=operate_addr + 8;        //不要忘记增加地址，每次8字节
                        read_sdram_counter <= read_sdram_counter + 1;
                        //[TODO]这种情况只是用于默认大小图片素材，后续需要添加新的逻辑
                        render_stat <= LOAD_LINE;
                    end 
                end
            end else if(render_stat == RENDER_LINE)begin
                render_begin <= 1;
                if( ~last_render_end & render_end)begin
                    render_begin <= 0;
                    if(line_counter == 31)begin
                        line_counter <= 0;
                        read_sdram_counter <= 0;
                        //完成了最后一轮渲染，彻底结束
                        draw_end <= 1;
                        render_stat <= DONE;
                    end else begin
                        line_counter <= line_counter + 1;
                        //开始下一行
                        operate_addr <= operate_addr + 8;  
                        read_sdram_counter <= 0;
                        render_stat <= LOAD_LINE;
                        vpos <= vpos + 1;   // 行起始地址：不变
                    end
                end
            end else begin
                if(done_delay_counter == 1'b0)begin
                    done_delay_counter <= 1'b1;
                end else begin
                    done_delay_counter <= 1'b0;
                    draw_end <= 1'b0;     // 恢复信号
                    render_stat <= IDLE;    // 等待下一次batch fill的请求
                end
            end
        end
        last_render_end <= render_end;
        last_cmd_done <= cmd_done;
    end 
endmodule