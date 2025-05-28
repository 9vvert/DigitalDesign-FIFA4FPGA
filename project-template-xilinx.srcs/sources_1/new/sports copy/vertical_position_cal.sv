/***********      仅仅用于垂直方向的速度计算     ************/
module vertical_position_caculator_copy
// 这些参数制定了能够移动的x,y范围，以及初始的x, y值
#(parameter Z_MIN = 0, Z_MAX = 100 , INIT_Z = 0)
(
    input game_clk,
    input rst,

    input [7:0] in_vertical_speed,     // z方向速度
    input in_vertical_signal,          // 0向上，1向下
    output reg [11:0] out_z,
    // 扩展参数，可以指定位置
    // 外界设置的时候，将set_pos_enable置为高电平，同时给出set_*_val的值，持续2个game_clk周期
    // [TODO]当扩展一个模块的功能时，再检查以前用过这个模块的地方，不要遗漏input
    input set_pos_enable,
    input [11:0] set_z_val
);
    //当前轮使用的速度和方向
    reg [7:0] vertical_speed;
    reg vertical_signal;
    // 更新：删去Mutex，使用更加灵活的方式
    reg [7:0] last_speed;   // 上一轮的速度
    //计数器计数，根据x，y方向的具体角度分量决定，实现“平滑过渡”
    reg [9:0] V_counter;
    reg [9:0] V_T;

    always @(posedge game_clk) begin
        if(rst) begin
            last_speed <= 8'hFF;        // 一个一定不会出现的值
            out_z <= INIT_Z;
            // 竖直运动部分
            V_counter <= 10'd0;
            V_T <= 10'd0;
            vertical_signal <= 1'b0;
            vertical_speed <= 0;
        end else if(set_pos_enable)begin
            out_z <= set_z_val;
        end else begin
            //对于z方向，不用考虑角度，比较简单
            if(last_speed != in_vertical_speed) begin
                vertical_speed = in_vertical_speed;         // 读取一轮新的
                last_speed = in_vertical_speed;             // 更新记录
                vertical_signal = in_vertical_signal;
                case(vertical_speed)
                    1: begin  V_T <= 10'd69; end
                    2: begin  V_T <= 10'd34; end
                    3: begin  V_T <= 10'd23; end
                    4: begin  V_T <= 10'd17; end
                    5: begin  V_T <= 10'd13; end
                    6: begin  V_T <= 10'd11; end
                    7: begin  V_T <= 10'd9; end
                    8: begin  V_T <= 10'd8; end
                    default: last_speed <= 10'hFF;      //如果竖直方向速度为0，将last_speed设置为特殊值，下一轮一定会重新执行上面的逻辑
                endcase
                V_counter <= 10'd0;
            end else begin
                if(V_counter == V_T - 1) begin
                    V_counter <= 10'd0;
                    if(vertical_signal == 0) begin  //向上
                        if(out_z < Z_MAX) begin
                            out_z <= out_z + 1;
                        end else begin
                            out_z <= out_z;
                        end
                    end else begin
                        if(out_z > Z_MIN) begin
                            out_z <= out_z - 1;
                        end else begin
                            out_z <= out_z;
                        end
                    end
                end else begin
                    V_counter <= V_counter + 1;
                end
            end
        end
    end

endmodule