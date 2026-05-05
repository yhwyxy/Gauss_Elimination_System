`timescale 1ns / 1ps

// ============================================================
// 顶层模块：高斯消元分布式计算系统
//  使用 packed 数组以兼容 Icarus Verilog
//  矩阵: [80:0][31:0] = 81 个 32-bit 元素
//  向量: [8:0][31:0]  = 9 个 32-bit 元素
// ============================================================
module Gauss_Elimination_System(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [80:0][31:0] matrix_external,
    input  logic [8:0][31:0]  b_external,
    output logic        done,
    output logic        error_flag,
    output logic [8:0][31:0]  solution
);
    localparam int N = 9;

    logic [80:0][31:0] m2s1_A;
    logic [8:0][31:0]  m2s1_b;
    logic               m2s1_start;
    logic               s1_done;
    logic [80:0][31:0] s1_U;
    logic [8:0][31:0]  s1_b;
    logic               s1_error;

    logic [80:0][31:0] m2s2_U;
    logic [8:0][31:0]  m2s2_b;
    logic               m2s2_start;
    logic               s2_done;
    logic [8:0][31:0]  s2_solution;
    logic               s2_error;

    Master master_inst(
        .clk(clk), .rst_n(rst_n), .start(start),
        .matrix_external(matrix_external), .b_external(b_external),
        .done_out(done), .error_flag_out(error_flag),
        .solution_out(solution),
        .fe_A_out(m2s1_A), .fe_b_out(m2s1_b), .fe_start_out(m2s1_start),
        .fe_done_in(s1_done), .fe_U_in(s1_U), .fe_b_out_in(s1_b),
        .fe_error_in(s1_error),
        .bs_U_out(m2s2_U), .bs_b_out(m2s2_b), .bs_start_out(m2s2_start),
        .bs_done_in(s2_done), .bs_solution_in(s2_solution),
        .bs_error_in(s2_error)
    );

    Forward_Elimination_Slave slave1_inst(
        .clk(clk), .rst_n(rst_n),
        .A_in(m2s1_A), .b_in(m2s1_b), .start_in(m2s1_start),
        .done_out(s1_done), .U_out(s1_U), .b_out(s1_b),
        .error_out(s1_error)
    );

    Back_Substitution_Slave slave2_inst(
        .clk(clk), .rst_n(rst_n),
        .U_in(m2s2_U), .b_in(m2s2_b), .start_in(m2s2_start),
        .done_out(s2_done), .solution_out(s2_solution),
        .error_out(s2_error)
    );

endmodule

// ============================================================
// 浮点运算辅助函数
//  Vivado: $bitstoshortreal / $shortrealtobits
//  Icarus Verilog (-DIVERILOG_SIM): real 类型手动转换
// ============================================================
package fp_utils;

`ifdef IVERILOG_SIM
    function automatic real bits32_to_real(input [31:0] bits);
        real sign, exponent, mantissa, value;
        begin
            sign = (bits[31]) ? -1.0 : 1.0;
            exponent = bits[30:23];
            mantissa = (exponent == 0) ? 0.0 : 1.0;
            mantissa = mantissa + bits[22:0] / (2.0**23);
            if (exponent != 0)
                value = sign * mantissa * (2.0**(exponent - 127.0));
            else
                value = sign * mantissa * (2.0**(-126.0));
            bits32_to_real = value;
        end
    endfunction

    function automatic [31:0] real_to_bits32(input real value);
        logic [31:0] result;
        real abs_val;
        integer exponent;
        real mantissa;
        begin
            if (value == 0.0) begin
                real_to_bits32 = 32'h00000000;
            end else begin
                result[31] = (value < 0.0) ? 1'b1 : 1'b0;
                abs_val = (value < 0.0) ? -value : value;
                exponent = 0;
                mantissa = abs_val;
                if (mantissa >= 2.0) begin
                    while (mantissa >= 2.0) begin mantissa = mantissa / 2.0; exponent = exponent + 1; end
                end else if (mantissa < 1.0) begin
                    while (mantissa < 1.0) begin mantissa = mantissa * 2.0; exponent = exponent - 1; end
                end
                result[30:23] = exponent + 127;
                result[22:0] = ((mantissa - 1.0) * (2.0**23));
                real_to_bits32 = result;
            end
        end
    endfunction

    function automatic [31:0] fp_add(input [31:0] a, input [31:0] b);
        fp_add = real_to_bits32(bits32_to_real(a) + bits32_to_real(b));
    endfunction
    function automatic [31:0] fp_sub(input [31:0] a, input [31:0] b);
        fp_sub = real_to_bits32(bits32_to_real(a) - bits32_to_real(b));
    endfunction
    function automatic [31:0] fp_mul(input [31:0] a, input [31:0] b);
        fp_mul = real_to_bits32(bits32_to_real(a) * bits32_to_real(b));
    endfunction
    function automatic [31:0] fp_div(input [31:0] a, input [31:0] b);
        fp_div = real_to_bits32(bits32_to_real(a) / bits32_to_real(b));
    endfunction
`else
    function automatic logic [31:0] fp_add(input logic [31:0] a, input logic [31:0] b);
        return $shortrealtobits($bitstoshortreal(a) + $bitstoshortreal(b));
    endfunction
    function automatic logic [31:0] fp_sub(input logic [31:0] a, input logic [31:0] b);
        return $shortrealtobits($bitstoshortreal(a) - $bitstoshortreal(b));
    endfunction
    function automatic logic [31:0] fp_mul(input logic [31:0] a, input logic [31:0] b);
        return $shortrealtobits($bitstoshortreal(a) * $bitstoshortreal(b));
    endfunction
    function automatic logic [31:0] fp_div(input logic [31:0] a, input logic [31:0] b);
        return $shortrealtobits($bitstoshortreal(a) / $bitstoshortreal(b));
    endfunction
`endif

    function automatic logic fp_is_zero(input [31:0] a);
        return (a[30:0] == 0);
    endfunction

endpackage

// ============================================================
// 主机模块 (Master)
// ============================================================
module Master(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [80:0][31:0] matrix_external,
    input  logic [8:0][31:0]  b_external,
    output logic        done_out,
    output logic        error_flag_out,
    output logic [8:0][31:0]  solution_out,
    output logic [80:0][31:0] fe_A_out,
    output logic [8:0][31:0]  fe_b_out,
    output logic        fe_start_out,
    input  logic        fe_done_in,
    input  logic [80:0][31:0] fe_U_in,
    input  logic [8:0][31:0]  fe_b_out_in,
    input  logic        fe_error_in,
    output logic [80:0][31:0] bs_U_out,
    output logic [8:0][31:0]  bs_b_out,
    output logic        bs_start_out,
    input  logic        bs_done_in,
    input  logic [8:0][31:0]  bs_solution_in,
    input  logic        bs_error_in
);
    localparam int N = 9;

    localparam S_IDLE   = 0;
    localparam S_SEND1  = 1;
    localparam S_WAIT1  = 2;
    localparam S_SEND2  = 3;
    localparam S_WAIT2  = 4;
    localparam S_VERIFY = 5;
    localparam S_DONE   = 6;
    localparam S_ERROR  = 7;

    reg [2:0] state;
    reg [80:0][31:0] A_reg;
    reg [8:0][31:0]  b_reg;
    integer i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            case (state)
                S_IDLE:   if (start)        state <= S_SEND1;
                S_SEND1:                   state <= S_WAIT1;
                S_WAIT1: begin
                    if (fe_error_in)       state <= S_ERROR;
                    else if (fe_done_in)   state <= S_SEND2;
                end
                S_SEND2:                   state <= S_WAIT2;
                S_WAIT2: begin
                    if (bs_error_in)       state <= S_ERROR;
                    else if (bs_done_in)   state <= S_VERIFY;
                end
                S_VERIFY:                  state <= S_DONE;
                S_DONE:   if (start)       state <= S_SEND1;
                S_ERROR:  if (start)       state <= S_SEND1;
                default:                   state <= S_IDLE;
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_out <= 0; error_flag_out <= 0;
            fe_start_out <= 0; bs_start_out <= 0;
            solution_out <= 0;
            A_reg <= 0; b_reg <= 0;
            fe_A_out <= 0; fe_b_out <= 0;
            bs_U_out <= 0; bs_b_out <= 0;
        end else begin
            fe_start_out <= 0;
            bs_start_out <= 0;
            case (state)
                S_IDLE: begin
                    done_out <= 0; error_flag_out <= 0;
                    if (start) begin
                        for (i = 0; i < N*N; i = i + 1) A_reg[i] <= matrix_external[i];
                        for (i = 0; i < N; i = i + 1)     b_reg[i] <= b_external[i];
                    end
                end
                S_SEND1: begin
                    for (i = 0; i < N*N; i = i + 1) fe_A_out[i] <= A_reg[i];
                    for (i = 0; i < N; i = i + 1)   fe_b_out[i] <= b_reg[i];
                    fe_start_out <= 1;
                end
                S_SEND2: begin
                    for (i = 0; i < N*N; i = i + 1) bs_U_out[i] <= fe_U_in[i];
                    for (i = 0; i < N; i = i + 1)   bs_b_out[i] <= fe_b_out_in[i];
                    bs_start_out <= 1;
                end
                S_VERIFY: begin
                    for (i = 0; i < N; i = i + 1) solution_out[i] <= bs_solution_in[i];
                end
                S_DONE: begin
                    done_out <= 1;
                    if (start) begin
                        for (i = 0; i < N*N; i = i + 1) A_reg[i] <= matrix_external[i];
                        for (i = 0; i < N; i = i + 1)     b_reg[i] <= b_external[i];
                    end
                end
                S_ERROR: begin
                    error_flag_out <= 1; done_out <= 1;
                    if (start) begin
                        for (i = 0; i < N*N; i = i + 1) A_reg[i] <= matrix_external[i];
                        for (i = 0; i < N; i = i + 1)     b_reg[i] <= b_external[i];
                    end
                end
            endcase
        end
    end
endmodule

// ============================================================
// 从机1：前向消元
//  多周期状态机，每周期处理一个消元步骤
// ============================================================
module Forward_Elimination_Slave(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [80:0][31:0] A_in,
    input  logic [8:0][31:0]  b_in,
    input  logic        start_in,
    output logic        done_out,
    output logic [80:0][31:0] U_out,
    output logic [8:0][31:0]  b_out,
    output logic        error_out
);
    import fp_utils::*;
    localparam int N = 9;

    localparam FE_IDLE = 0, FE_RECV = 1, FE_ELIM = 2, FE_ERR = 3, FE_DONE = 4;

    reg [2:0]  fe_state;
    reg [80:0][31:0] U;
    reg [8:0][31:0]  bv;
    reg [31:0] factor;
    integer    pivot_row, elim_row, elim_col, i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fe_state <= FE_IDLE; done_out <= 0; error_out <= 0;
            pivot_row <= 0; elim_row <= 0; elim_col <= 0; factor <= 0;
            U <= 0; bv <= 0; U_out <= 0; b_out <= 0;
        end else begin
            case (fe_state)
                FE_IDLE: begin
                    done_out <= 0; error_out <= 0;
                    if (start_in) fe_state <= FE_RECV;
                end

                FE_RECV: begin
                    for (i = 0; i < N*N; i = i + 1) U[i]  <= A_in[i];
                    for (i = 0; i < N; i = i + 1)   bv[i] <= b_in[i];
                    pivot_row <= 0; elim_row <= 1; elim_col <= 0;
                    fe_state <= FE_ELIM;
                end

                FE_ELIM: begin
                    if (pivot_row >= N - 1) begin
                        for (i = 0; i < N*N; i = i + 1) U_out[i] <= U[i];
                        for (i = 0; i < N; i = i + 1)   b_out[i] <= bv[i];
                        done_out <= 1; fe_state <= FE_DONE;

                    end else if (elim_row >= N) begin
                        pivot_row <= pivot_row + 1;
                        elim_row  <= pivot_row + 2;
                        elim_col  <= 0;

                    end else begin
                        if (elim_col == 0) begin
                            if (fp_is_zero(U[pivot_row * N + pivot_row])) begin
                                fe_state <= FE_ERR;
                            end else begin
                                factor <= fp_div(U[elim_row * N + pivot_row],
                                                 U[pivot_row * N + pivot_row]);
                            end
                            elim_col <= pivot_row + 1;

                        end else if (elim_col <= N) begin
                            U[elim_row * N + (elim_col - 1)] <=
                                fp_sub(U[elim_row * N + (elim_col - 1)],
                                       fp_mul(factor, U[pivot_row * N + (elim_col - 1)]));
                            elim_col <= elim_col + 1;

                        end else begin
                            bv[elim_row] <= fp_sub(bv[elim_row],
                                                   fp_mul(factor, bv[pivot_row]));
                            elim_row <= elim_row + 1;
                            elim_col <= 0;
                        end
                    end
                end

                FE_ERR: begin
                    error_out <= 1; done_out <= 1; fe_state <= FE_DONE;
                end

                FE_DONE: begin
                    if (!start_in) fe_state <= FE_IDLE;
                end
            endcase
        end
    end
endmodule

// ============================================================
// 从机2：回代求解
// ============================================================
module Back_Substitution_Slave(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [80:0][31:0] U_in,
    input  logic [8:0][31:0]  b_in,
    input  logic        start_in,
    output logic        done_out,
    output logic [8:0][31:0]  solution_out,
    output logic        error_out
);
    import fp_utils::*;
    localparam int N = 9;

    localparam BS_IDLE = 0, BS_RECV = 1, BS_SUM = 2, BS_DIV = 3, BS_DONE = 4;

    reg [2:0]  bs_state;
    reg [80:0][31:0] U;
    reg [8:0][31:0]  bv, x;
    reg [31:0] sum_reg;
    integer    cur_i, cur_j, i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bs_state <= BS_IDLE; done_out <= 0; error_out <= 0;
            cur_i <= 0; cur_j <= 0; sum_reg <= 0;
            U <= 0; bv <= 0; x <= 0; solution_out <= 0;
        end else begin
            case (bs_state)
                BS_IDLE: begin
                    done_out <= 0; error_out <= 0;
                    if (start_in) bs_state <= BS_RECV;
                end

                BS_RECV: begin
                    for (i = 0; i < N*N; i = i + 1) U[i] <= U_in[i];
                    for (i = 0; i < N; i = i + 1) begin bv[i] <= b_in[i]; x[i] <= 0; end
                    cur_i <= N - 1; cur_j <= N; sum_reg <= 0;
                    bs_state <= BS_SUM;
                end

                BS_SUM: begin
                    if (cur_i < 0) begin
                        for (i = 0; i < N; i = i + 1) solution_out[i] <= x[i];
                        done_out <= 1; bs_state <= BS_DONE;
                    end else if (cur_j >= N) begin
                        bs_state <= BS_DIV;
                    end else begin
                        sum_reg <= fp_add(sum_reg, fp_mul(U[cur_i * N + cur_j], x[cur_j]));
                        cur_j <= cur_j + 1;
                    end
                end

                BS_DIV: begin
                    if (cur_i < 0) begin
                        for (i = 0; i < N; i = i + 1) solution_out[i] <= x[i];
                        done_out <= 1; bs_state <= BS_DONE;
                    end else if (fp_is_zero(U[cur_i * N + cur_i])) begin
                        error_out <= 1; x[cur_i] <= 0;
                        sum_reg <= 0; cur_i <= cur_i - 1; cur_j <= cur_i;
                        bs_state <= BS_SUM;
                    end else begin
                        x[cur_i] <= fp_div(fp_sub(bv[cur_i], sum_reg),
                                           U[cur_i * N + cur_i]);
                        sum_reg <= 0; cur_i <= cur_i - 1; cur_j <= cur_i;
                        bs_state <= BS_SUM;
                    end
                end

                BS_DONE: begin
                    if (!start_in) bs_state <= BS_IDLE;
                end
            endcase
        end
    end
endmodule
