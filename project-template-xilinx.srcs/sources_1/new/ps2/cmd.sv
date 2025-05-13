/**************  与上层的通讯协议 ***********/
// 输出的action_cmd从0到7位分别是L1,L2,R1,R2,A,B,X,Y

//  上层读取cmd_ready后，读取命令，并将read_ready置为1
//  本层读取到read_ready后，将cmd_ready置为0，进行下一轮

// 调用ps2模块，将处理好后的信号进行优先级处理、输出action命令等
module cmd_decoder
// 暂时设置：不按加速键时，最大速度为3
// 只需要对Button消抖，因为仅仅是一个高电平就能够让游戏逻辑变化
// 对于Handle，微小的抖动对游戏没有任何影响
#(parameter RUN_MAX_V = 3, BUTTON_DELAY = 3)
(
    //基础
    input rst,
    //ps2部分
    input  wire ps2_clk,          // 100kHz， 10us一次
    output wire pmod_io1,    // MOSI
    input wire pmod_io2,    // MISO
    output wire pmod_io3,    // SCLK    //手动控制，不再使用外部时钟
    output reg pmod_io4,    // CS

    //[TODO]仔细思考模块设计的原则
    // 原本的计划是将player.sv中的一些信息传递过来，但是这会导致时序问题，需要进行缓冲。
    // 事实上，更好的方法似乎是仅仅传递出cmd，
    //对外输出，实现控制的效果(这里只是输出一个信号进行“驱动”，真正的判定是在模块内部实现的)
    output reg [7:0] left_angle,
    output reg [7:0] right_angle,
    output reg [7:0] action_command
    //[TODO]这里删去了一些等待的逻辑，是否可能导致时序问题？
);
    `include "trangleval.sv"
    `include "line.sv" 

    reg [7:0] ps2_mode;
    reg [7:0] btn_grp1;
    reg [7:0] btn_grp2;
    reg [7:0] rhandle_X;
    reg [7:0] rhandle_Y;
    reg [7:0] lhandle_X;
    reg [7:0] lhandle_Y;
    reg ready; 

    reg [7:0] last_btn_grp2;    //存储上次读取的btn_grp，检测到变化时清空计数器
    // reg [7:0] last_btn_grp2;
    reg [3:0] L1_counter;
    reg [3:0] L2_counter;
    reg [3:0] R1_counter;
    reg [3:0] R2_counter;
    reg [3:0] A_counter;
    reg [3:0] B_counter;
    reg [3:0] X_counter;
    reg [3:0] Y_counter;

    ps2 u_ps2(
        // .debug_number(number),
        .ps2_clk(ps2_clk),    
        .rst(rst) ,      
        .ps2_mode(ps2_mode), 
        .btn_grp1(btn_grp1), 
        .btn_grp2(btn_grp2),
        .rhandle_X(rhandle_X),
        .rhandle_Y(rhandle_Y),
        .lhandle_X(lhandle_X),
        .lhandle_Y(lhandle_Y),
        .ready(ready),
        .pmod_io1(pmod_io1), // MOSI
        .pmod_io2(pmod_io2), // MISO
        .pmod_io3(pmod_io3), // SCLK
        .pmod_io4(pmod_io4)  // CS
    );
    // 这里选择和下层的ps2使用同一个时钟，而不是使用更慢的game_clk
    reg cmd_done_delay;     // 当一轮信号处理完成后，进行1ms的延时，确保其稳定
    always @(posedge ps2_clk) begin
        if(rst) begin
            left_angle <= 8'hFF;
            right_angle <= 8'hFF;
            action_command <= 8'd0; //IDLE
            cmd_done_delay <= 8'hFF;
            last_btn_grp2 <= 8'hFF;
            //因为ready是在内部输出的，所以这里不应该再进行初始化
            //清空计数器
            L1_counter <= 4'd0;
            L2_counter <= 4'd0;
            R1_counter <= 4'd0;
            R2_counter <= 4'd0;
            A_counter <= 4'd0;
            B_counter <= 4'd0;
            X_counter <= 4'd0;
            Y_counter <= 4'd0;
        end else if(ready)begin
            //计数器在电位变化的时候归零
            if(btn_grp2[0] != last_btn_grp2[0])begin
                L2_counter = 4'd0;
            end
            if(btn_grp2[1] != last_btn_grp2[1])begin
                R2_counter = 4'd0;
            end
            if(btn_grp2[2] != last_btn_grp2[2])begin
                L1_counter = 4'd0;
            end
            if(btn_grp2[3] != last_btn_grp2[3])begin
                R1_counter = 4'd0;
            end
            if(btn_grp2[4] != last_btn_grp2[4])begin
                Y_counter = 4'd0;
            end
            if(btn_grp2[5] != last_btn_grp2[5])begin
                B_counter = 4'd0;
            end
            if(btn_grp2[6] != last_btn_grp2[6])begin
                A_counter = 4'd0;
            end
            if(btn_grp2[7] != last_btn_grp2[7])begin
                X_counter = 4'd0;
            end
            // 当计数器达到阈值后不再计数，得益于阻塞赋值，如果电位发生变化，计数器会先清零再执行下面的过程
            if(L1_counter == BUTTON_DELAY)begin
                action_cmd[0] <= btn_grp2[2];   // L1
            end begin
                L1_counter = L1_counter + 4'd1;
            end
            if(L2_counter == BUTTON_DELAY)begin
                action_cmd[1] <= btn_grp2[0];   // L2
            end begin
                L2_counter = L2_counter + 4'd1;
            end
            if(L2_counter == BUTTON_DELAY)begin
                action_cmd[2] <= btn_grp2[3];   // R1
            end begin
                R1_counter = R1_counter + 4'd1;
            end
            if(L2_counter == BUTTON_DELAY)begin
                action_cmd[3] <= btn_grp2[1];   // R2
            end begin
                R2_counter = R2_counter + 4'd1;
            end
            if(L2_counter == BUTTON_DELAY)begin
                action_cmd[4] <= btn_grp2[6];   // A
            end begin
                A_counter = A_counter + 4'd1;
            end
            if(L2_counter == BUTTON_DELAY)begin
                action_cmd[5] <= btn_grp2[5];   // B
            end begin
                B_counter = B_counter + 4'd1;
            end
            if(L2_counter == BUTTON_DELAY)begin
                action_cmd[6] <= btn_grp2[7];   // X
            end begin
                X_counter = X_counter + 4'd1;
            end
            if(L2_counter == BUTTON_DELAY)begin
                action_cmd[7] <= btn_grp2[4];   // Y
            end begin
                Y_counter = Y_counter + 4'd1;
            end

            last_btn_grp2 = btn_grp2;
            

            // ready的时候能够保证btn_grp等信号稳定,这是通过ready协议方法+ps2完成后主动延时的方法实现的
            //测试：ready=1代表这一个周期的手柄信号可以读取，
            left_X <= lhandle_X;
            left_Y <= lhandle_Y;
            cmd_ready <= 1'b0;          // [Special] ，保证不论有没有特殊情况，都能够将cmd_ready归零

            //radius超过40才认为有效（事实上，如果radius过小，计算出角度的浮动可能也较大）
            if(distance(8'h80, 8'h80, lhandle_X, lhandle_Y) >= 32'd2500)begin
                if(lhandle_X == 8'h80) begin
                    if(lhandle_Y < 8'h7F) begin
                        left_angle <= 0;
                    end else begin
                        left_angle <= 36;
                    end
                end else if(lhandle_Y == 8'h7F) begin
                    if(lhandle_X < 8'h80) begin
                        left_angle <= 54;
                    end else begin
                        left_angle <= 18;
                    end
                end else begin
                    left_angle <= vec2angle(8'h80, 8'h80, lhandle_X, 255 - lhandle_Y);
                end
            end else begin
                left_angle <= 8'hFF;        // FF表示特殊角度：没有方向
            end
            if(distance(8'h80, 8'h80, rhandle_X, rhandle_Y) >= 32'd2500)begin
                if(rhandle_X == 8'h80) begin
                    if(rhandle_Y < 8'h7F) begin
                        right_angle <= 0;
                    end else begin
                        right_angle <= 36;
                    end
                end else if(rhandle_Y == 8'h7F) begin
                    if(rhandle_X < 8'h80) begin
                        right_angle <= 54;
                    end else begin
                        right_angle <= 18;
                    end
                end else begin
                    right_angle <= vec2angle(8'h80, 8'h80, rhandle_X, 255 - rhandle_Y);
                end
            end else begin
                right_angle <= 8'hFF;
            end
            //优先级暂时设置为A > B > X > Y
            // IDLE: 0， ABXY为1234
            //[TODO]后续需要完善功能
            if(btn_grp2[4] == 0) begin
                action_command <= 6'd1;
            end else if(btn_grp2[5] == 0) begin
                action_command <= 6'd2;
            end else if(btn_grp2[6] == 0) begin
                action_command <= 6'd3;
            end else if(btn_grp2[7] == 0) begin
                action_command <= 6'd4;
            end else begin
                action_command <= 6'd0;     //IDLE
            end

        end
    end
endmodule