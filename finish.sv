`timescale 1ns / 1ps

// 鍋囪鐨処P鏍告枃浠讹紝鎮ㄩ渶瑕佹牴鎹疄闄呯敓鎴愮殑鏂囦欢杩涜璋冩暣
//`include "fp_add.v"
//`include "fp_mult.v"
//`include "fp_div.v"
//`include "fp_sub.v"

module Gauss_Elimination_System(
    input logic clk,
    input logic rst_n,
    input logic start,
    output logic done,
    output logic error_flag
);
    parameter int N = 9;  // 鐭╅樀澶у皬
    parameter int Width = 32;  // 娴偣鏁板搴?
    parameter int Integer_Depth = N * N;

    logic [Width-1:0] matrix[N*N-1:0];
    logic [Width-1:0] upper_triangular_matrix[N*N-1:0];
    logic [Width-1:0] solution[N-1:0];
    logic [Width-1:0] a, b; // Example operands for floating point operations
    logic [Width-1:0] fp_add_result, fp_sub_result, fp_mul_result, fp_div_result;
    logic forward_done, back_sub_done, verify_done;

    // 娴偣杩愮畻鍗曞厓鐨勫疄渚?
    fp_add fp_add_inst(
        .aclk(clk),
        .aresetn(rst_n),
        .s_axis_a_tdata(a),
        .s_axis_b_tdata(b),
        .m_axis_result_tdata(fp_add_result)
        );
    
    fp_sub fp_sub_inst(
        .aclk(clk),
        .aresetn(rst_n),
        .s_axis_a_tdata(a),
        .s_axis_b_tdata(b),
        .m_axis_result_tdata(fp_sub_result)
    );

    fp_mult fp_mult_inst(
        .aclk(clk),
        .aresetn(rst_n),
        .s_axis_a_tdata(a),
        .s_axis_b_tdata(b),
        .m_axis_result_tdata(fp_mult_result)
    );

    fp_div fp_div_inst(
        .aclk(clk),
        .aresetn(rst_n),
        .s_axis_a_tdata(a),
        .s_axis_b_tdata(b),
        .m_axis_result_tdata(fp_div_result)
    );


    // 鍓嶅悜娑堝厓妯″潡
    Forward_Elimination forward_elim(
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .matrix_input(matrix),
        .upper_triangular_matrix(upper_triangular_matrix),
        .done(forward_done)
    );

    // 鍥炰唬妯″潡
    Back_Substitution back_sub(
        .clk(clk),
        .reset(rst_n),
        .start(forward_done),
        .upper_triangular_matrix(upper_triangular_matrix),
        .solution(solution),
        .done(back_sub_done)
    );

    // 瑙ｅ喅鏂规楠岃瘉妯″潡
    Verify_Solution verifier(
        .clk(clk),
        .reset(rst_n),
        .start(back_sub_done),
        .solution(solution),
        .original_matrix(matrix),
        .done(verify_done),
        .error_flag(error_flag)
    );

    // 鎺у埗閫昏緫浠ョ鐞嗘暣涓绠楄繃绋?
    always @(posedge clk) begin
        if (rst_n == 1'b0) begin
            done <= 1'b0;
        end else if (verify_done) begin
            done <= 1'b1; // 琛ㄧず鏁翠釜璁＄畻杩囩▼瀹屾垚
        end
    end

endmodule

// Forward Elimination Module Implementation
module Forward_Elimination(
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic [Width-1:0] matrix_input[81],
    output logic [Width-1:0] upper_triangular_matrix[81],
    output logic done
);
    localparam int Width = 32;
    localparam int N = 8;
    integer i, j, k;
    logic [Width-1:0] factor;
    logic [Width-1:0] matrix_working[81];

    always @(posedge clk) begin
        if (!rst_n) begin
            done <= 0;
            for (i = 0; i < 80; i++) begin
                matrix_working[i] <= matrix_input[i];
            end
        end else if (start) begin
            for (i = 0; i < N; i++) begin
                for (j = i + 1; j < N; j++) begin
                    factor = matrix_working[j * N + i] / matrix_working[i * N + i];  // Floating point division
                    for (k = i; k < N; k++) begin
                        matrix_working[j * N + k] <= matrix_working[j * N + k] - factor * matrix_working[i * N + k];  // Floating point subtraction
                    end
                end
            end
            for (i = 0; i < 81; i++) begin
                upper_triangular_matrix[i] <= matrix_working[i];
            end
            done <= 1;
        end
    end
endmodule

// Back Substitution Module Implementation
module Back_Substitution(
    input logic clk,
    input logic reset,
    input logic start,
    input logic [Width-1:0] upper_triangular_matrix[81],
    output logic [Width-1:0] solution[8:0],
    output logic done
);
    localparam int Width = 32;
    localparam int N = 8;
    
    integer i, j;
    logic [Width-1:0] sum;

    always @(posedge clk) begin
        if (reset) begin
            done <= 0;
        end else if (start) begin
            for (i = 8; i >= 0; i = i - 1) begin
                sum = 0;
                for (j = i + 1; j < 9; j = j + 1) begin
                    sum = sum + upper_triangular_matrix[i*9 + j] * solution[j];  // Floating point multiplication
                end
                solution[i] = (upper_triangular_matrix[i*9 + i] - sum) / upper_triangular_matrix[i*9 + i];  // Floating point division and subtraction
            end
            done <= 1;
        end
    end
endmodule

// Verify Solution Module Implementation
module Verify_Solution(
    input logic clk,
    input logic reset,
    input logic start,
    input logic [Width-1:0] solution[8:0],
    input logic [Width-1:0] original_matrix[81],
    output logic done,
    output logic error_flag
);
    localparam int Width = 32;
    localparam int N = 8;
    
    integer i, j;
    logic [Width-1:0] check_sum;

    always @(posedge clk) begin
        if (reset) begin
            done <= 0;
            error_flag <= 0;
        end else if (start) begin
            for (i = 0; i < 9; i++) begin
                check_sum = 0;
                for (j = 0; j < 9; j++) begin
                    check_sum = check_sum + original_matrix[i*9 + j] * solution[j];  // Floating point multiplication and addition
                end
                // Assume that the right-hand side of equation is stored at the end of each row
                if (check_sum != original_matrix[i*9 + 9]) begin
                    error_flag <= 1;
                end
                end
            done <= 1;
        end
    end
endmodule
