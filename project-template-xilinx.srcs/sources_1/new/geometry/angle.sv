// 一些角度的基本操作

//给定任意角ang1，一个小于36的角ang2，返回ang1+ang2
package AngleLib;
    function automatic [7:0] angle_add(
        input [7:0] ang1,
        input [7:0] ang2
    );
        angle_add = (ang1 + ang2 >= 72) ? ((ang1 + ang2) - 72) : (ang1 + ang2);
    endfunction

    //给定任意角ang1，一个小于36的角ang2，返回ang1-ang2
    function automatic [7:0] angle_sub(
        input [7:0] ang1,
        input [7:0] ang2
    );
        angle_sub = (ang1 >= ang2) ? (ang1 - ang2) : ((ang1 + 72) - ang2);
    endfunction

    //给定ang1和ang2，返回二者差值的绝对值（取最小的一个）
    function automatic [7:0] rel_angle_val(
        input [7:0] ang1,
        input [7:0] ang2
    );
        automatic logic[7:0]delta_angle = (ang1 > ang2) ? (ang1 - ang2) : (ang2 - ang1);
        rel_angle_val = ( delta_angle < (72 - delta_angle) ) ? (delta_angle) : (72 - delta_angle);
    endfunction

    //给定ang1和ang2，如果ang2在ang1的左侧：0， 右侧：1， 重合：2， 相对：3
    function automatic [1:0] rel_angle_pos(
        input [7:0] ang1,
        input [7:0] ang2
    );
        automatic logic [7:0] relative_angle = rel_angle_val(ang1,ang2); //获得相对差值
        if(ang1 == ang2) begin
            rel_angle_pos = 2'd2;
        end else if( (ang1+8'd32 == ang2) || (ang2+8'd32 == ang1 )) begin
            rel_angle_pos = 2'd3;
        end else begin  // 两侧
            automatic logic [7:0] add_result = angle_add(ang1,relative_angle);
            if(add_result == ang2) begin
                rel_angle_pos = 2'd1;
            end else begin
                rel_angle_pos = 2'd0;
            end
        end
    endfunction

    function automatic [7:0] near_8_direction(
        input [7:0] angle
    );
        if (angle >= 68 || angle <= 4)
            near_8_direction = 3'd0;
        else if (angle >= 5 && angle <= 13)
            near_8_direction = 3'd1;
        else if (angle >= 14 && angle <= 22)
            near_8_direction = 3'd2;
        else if (angle >= 23 && angle <= 31)
            near_8_direction = 3'd3;
        else if (angle >= 32 && angle <= 40)
            near_8_direction = 3'd4;
        else if (angle >= 41 && angle <= 49)
            near_8_direction = 3'd5;
        else if (angle >= 50 && angle <= 58)
            near_8_direction = 3'd6;
        else if (angle >= 59 && angle <= 67)
            near_8_direction = 3'd7;
        else
            near_8_direction = 3'd0; // 默认值
    endfunction
endpackage