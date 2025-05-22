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
    output reg sram_io_req,        //读写请求
    output reg [19:0] times,       //读写次数
    output reg wr,                 //是否选择“写”
    output reg [19:0] addr,
    output reg [31:0] din,          // 渲染信息
    input wire [31:0] dout
);
    // 总控制
    reg [3:0] render_stat;  //渲染器状态
    localparam [3:0] IDLE=0, LOAD_LINE=1, RENDER_LINE=2, DONE=3;
    reg [5:0] line_counter;         //按照行来渲染，每次渲染
    reg [7:0] line_buffer [63:0];   //像素行缓冲
    reg [1:0] done_delay_counter;

    /***********  渲染引擎   ***********/
    reg mode;
    reg render_begin;
    wire render_end;
    reg [29:0] vm_start;      // 该显存开始的地址
    reg [11:0] half_img_width;    //[TODO]一定要注意：这里用半宽
    reg [11:0] half_img_height;
    reg [11:0] h_pos;          // 物体在显存中渲染的坐标
    reg [11:0] v_pos;
    // mode = 0 时， sprite_addr有效
    reg [29:0] sprite_addr;    // 图片数据存放的地址（线性存储）
    // mode = 1 时， 下列有效
    reg [29:0] vm_background_start;   //背景在显存中另外开辟一个区域，和显存等大
    reg [11:0] bg_hpos;
    reg [11:0] bg_vpos;

    // 辅助：将stat, angle等映射到具体的地址
    logic [2:0] direction;  // 计算出的方向值
    logic [7:0] angle;
    logic [3:0] stat;
    logic [29:0] result_addr;
    assign angle = render_param.angle;
    assign stat = render_param.stat;
    always_comb begin
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
    line_render u_line_render(
        .sprite_render_ui_clk(vm_renderer_ui_clk),
        .ui_rst(ui_rst),
        .mode(mode),         // 0:将线性存储的数据渲染到显存的指定坐标；  1：将背景的某一块补全
        .render_begin(render_begin),
        .render_end(render_end),
        .vm_start(vm_start),       // 该显存开始的地址
        .half_img_width(half_img_width),    //[TODO]一定要注意：这里用半宽
        .half_img_height(half_img_height),
        .hpos(h_pos),          // 物体在显存中渲染的坐标
        .vpos(v_pos),
        .sprite_addr(sprite_addr),    // 图片数据存放的地址（线性存储）
        .vm_background_start(vm_background_start),   //背景在显存中另外开辟一个区域，和显存等大
        .bg_hpos(bg_hpos),
        .bg_vpos(bg_vpos),
        //控制SDRAM
        .sdram_cmd(sdram_cmd),          //命令，  0无效，1读取，2写入
        .operate_addr(operate_addr),      //地址
        .write_data(write_data),
        .read_data(read_data),
        .cmd_done(cmd_done),
        //控制SRAM
        .sram_io_req(sram_io_req),
        .wr(wr),
        .times(times),
        .addr(addr),
        .din(din),
        .dout(dout)
    );

    /***********  渲染状态机  ***********/
    reg last_render_end;      //捕捉上升沿
    always @(posedge vm_renderer_ui_clk)begin
        if(ui_rst)begin
            done_delay_counter <= 1'b0;
            render_stat <= IDLE;
            last_render_end <= 1'b0;
        end else begin
            if(render_stat == IDLE)begin
                if(draw_begin)begin
                    render_stat <= RENDER;
                end
            end else if(render_stat == RENDER)begin
                // dst 渲染目标帧的起始位置、渲染坐标、图片大小
                vm_start <= (vm_flag ? BUF2_START : BUF1_START);
                half_img_height <= (render_param.height >> 1);
                half_img_width <= (render_param.width >> 1);
                h_pos <= render_param.h_pos;
                v_pos <= render_param.v_pos;
                //type中，除了填补背景会直接改变sprite_render的mode外，其余的type只是为了公式化寻找目标
                if(render_param.render_type == 0)begin
                    mode <= 1'b1;
                    render_begin <= 1'b1;
                    // src
                    vm_background_start <= BG_FRAME_START;
                    bg_hpos <= render_param.h_pos;
                    bg_vpos <= render_param.v_pos;
                    if(~last_render_end & render_end)begin
                        render_begin <= 1'b0;
                        draw_end <= 1'b1;
                        render_stat <= DONE;
                    end
                end else if(render_param.render_type == 1)begin
                    mode <= 1'b0;
                    render_begin <= 1'b1;
                    // src
                    sprite_addr <= result_addr; // 在always_comb中计算

                    if(~last_render_end & render_end)begin
                        render_begin <= 1'b0;
                        draw_end <= 1'b1;
                        render_stat <= DONE;
                    end
                end else if(render_param.render_type == 2)begin
                    mode <= 1'b0;
                    render_begin <= 1'b1;
                    // src
                    //[TODO]检查这里新增的base_addr是否正确
                    sprite_addr <= result_addr + 1000*512; // 在always_comb中计算

                    if(~last_render_end & render_end)begin
                        render_begin <= 1'b0;
                        draw_end <= 1'b1;
                        render_stat <= DONE;
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
    end 
endmodule