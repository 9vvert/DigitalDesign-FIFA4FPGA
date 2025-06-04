// 作用只是预判球的轨迹，并向其移动。
// 上层的决策树会在其距离球最近的时候，让其进入TACKLE状态
module a_catch(
    input [11:0] x1,    //持球人
    input [11:0] y1,
    input PlayerInfo self_info,
    input [7:0] shoot_angle,        // 传球的角度
    input [2:0] shoot_level,
    input shoot_type,       // 0为近传，1为远传
    output [2:0] force_level,       // 外界的受排斥等级 这种情况下应该为5级
    output enable_sprint,           //是否允许冲刺
    output [31:0]catch_x_pos,
    output [31:0]catch_x_neg,
    output [31:0]catch_y_pos,
    output [31:0]catch_y_neg

);
    assign force_level = 2;
    assign enable_sprint = 0;
    logic [11:0] radius;        //预测半径[TODO]后续可能会修改数值
    logic [11:0] aim_x;
    logic [11:0] aim_y;
    always_comb begin
        // 注意下面的radius是除以12后的数值
        if(shoot_type == 0)begin
            //近传
            radius =    (shoot_level==1) ? 7 :
                        (shoot_level==2) ? 13:
                        (shoot_level==3) ? 19:
                        (shoot_level==4) ? 25:
                                            34;        // 最后一个给的宽泛一些
        end else begin
            //远传
            radius =    (shoot_level==1) ? 19 :
                        (shoot_level==2) ? 23 :
                        (shoot_level==3) ? 27 :
                        (shoot_level==4) ? 32:
                                            36;
        end

        if(shoot_angle < 8'd18) begin
            aim_x <= x1 + radius*sin(shoot_angle);
            aim_y <= y1 + radius*cos(shoot_angle);
        end else if(shoot_angle < 8'd36) begin
            aim_x <= x1 + radius*cos(shoot_angle - 8'd18);
            aim_y <= y1 - radius*sin(shoot_angle - 8'd18);
        end else if(shoot_angle < 8'd54) begin
            aim_x <= x1 - radius*sin(shoot_angle - 8'd36);
            aim_y <= y1 - radius*cos(shoot_angle - 8'd36);
        end else if(shoot_angle < 8'd72)begin
            aim_x <= x1 - radius*cos(shoot_angle - 8'd54);
            aim_y <= y1 + radius*sin(shoot_angle - 8'd54);
        end else begin
            aim_x <= x1;
            aim_y <= y1;
        end 
        // aim_x, aim_y的矩形区域
        // x
        if(self_info.x + 30 < aim_x)begin
            catch_x_pos = 200;
            catch_x_neg = 0;
        end else if(self_info.x > aim_x + 30)begin
            catch_x_pos = 0;
            catch_x_neg = 200;
        end else begin
            catch_x_pos = 0;
            catch_x_neg = 0;
        end
        // y
        if(self_info.y + 30 < aim_y)begin
            catch_y_pos = 200;
            catch_y_neg = 0;
        end else if(self_info.y > aim_y + 30)begin
            catch_y_pos = 0;
            catch_y_neg = 200;
        end else begin
            catch_y_pos = 0;
            catch_y_neg = 0;
        end
    end


endmodule