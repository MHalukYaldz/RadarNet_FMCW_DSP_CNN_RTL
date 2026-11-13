`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Mustafa Haluk Yaldız
// Module Name: axis_transaction
// Target Devices: Pnyq-Z2 
// Tool Versions: Vivado 2025.2
//////////////////////////////////////////////////////////////////////////////////

interface axis_uvm_if;

    logic   aclk;
    logic   aresetn;
    
    logic [31:0]s_axis_tdata;
    logic       s_axis_tvalid;
    logic       s_axis_tready;
    logic       s_axis_tlast;
    
    logic [31:0]m_axis_tdata;   
    logic       m_axis_tvalid;  
    logic       m_axis_tready;  
    logic       m_axis_tlast;   
    
endinterface