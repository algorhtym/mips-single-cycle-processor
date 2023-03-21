library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- This is the top level entity for the Single Cycle Processor project

entity singleCycleProc is 
    port (
        valueSelect : in STD_LOGIC_VECTOR(2 downto 0);
        GClock, GReset: in STD_LOGIC;
        muxOut : out STD_LOGIC_VECTOR(7 downto 0);
        instructionOut : out STD_LOGIC_VECTOR(31 downto 0);
        BranchOut, ZeroOut, MemWriteOut,RegWriteOut : out STD_LOGIC
        );

end singleCycleProc;

architecture structural of singleCycleProc is 

    -- signal declarations
    signal i_muxOut : std_logic_vector(7 downto 0);
    signal i_instructionOut : std_logic_vector(31 downto 0);
    signal i_BranchOut, i_ZeroOut, i_MemWriteOut, i_RegWriteOut : std_logic;
    signal i_PC, i_ALUResult, i_ReadData1, i_ReadData2, i_WriteData, i_other : std_logic_vector(7 downto 0);
    signal i_RegDst, i_MemtoReg, i_MemRead,
           i_ALUOp1, i_ALUOp0, i_ALUSrc, i_Jump : std_logic;

    -- PC+4 adder signals
    signal i_PC_plus4 : std_logic_vector(7 downto 0);

    -- PC Register signals
    signal i_PCReg_in : std_logic_vector(7 downto 0);


    -- Register File signals
    signal rs, rt, rd : std_logic_vector(4 downto 0);
    --signal reg_write_data : std_logic_vector(7 downto 0);

    -- ALU signals
    signal i_ALU_cont : std_logic_vector(3 downto 0);
    signal ALU_mux_out : std_logic_vector(7 downto 0);
    signal sign_trunc_out : std_logic_vector(7 downto 0);

    -- Branch signals
    signal br_targ_offset, br_targ_addr, br_result : std_logic_vector(7 downto 0);
    signal br_control : std_logic;

    -- Jump signals
    signal jmp_targ_addr : std_logic_vector(7 downto 0);

    -- RAM signals
    signal i_ram_read_data : std_logic_vector(7 downto 0);

    



    -- component declarations

    -- ------------------------------------------
    -- INSTRUCTION 
    -- Instruction Memory (32 bits, 256 instructions) (256x32) LPM_ROM function
    component instr_mem IS
        PORT (
            address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
            clock		: IN STD_LOGIC;
            q		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
        );
    END component;

    -- ------------------------------------------
    -- MUX
    -- 8x2x1 MUX (memory mux, ALU mux, branch mux, jump mux)
    component mux_8bit_2x1 is
        port (
            data_0, data_1 : in std_logic_vector(7 downto 0);
            sel : in std_logic;
            data_out : out std_logic_vector(7 downto 0)
        );
    end component;

    -- 5x2x1 MUX (Register Write MUX)
    component mux_5bit_2x1 is
        port (
            data_0, data_1 : in std_logic_vector(4 downto 0);
            sel : in std_logic;
            data_out : out std_logic_vector(4 downto 0)
        );
    end component;

    -- ------------------------------------------
    -- CONTROL
    -- Control Unit
    component ssp_control is
        port (
            instr : in std_logic_vector(5 downto 0);
            RegDst, ALUSrc, MemtoReg, RegWrite, MemRead, 
            MemWrite, Branch, ALUOp1, ALUOp0, Jump : out std_logic
        );
    end component;

    -- ------------------------------------------
    -- REGISTERS
    -- Register File (8x8bit registers)
    component register_file_8x8 is
        port (
            clk   : in std_logic;
            reset_bar : in std_logic;
            read_reg1, read_reg2 : in std_logic_vector(4 downto 0);
            write_reg : in std_logic_vector(4 downto 0);
            write_data : in std_logic_vector(7 downto 0);
            wr : in  std_logic;
            read_data1 : out std_logic_vector(7 downto 0);
            read_data2 : out std_logic_vector(7 downto 0)
        );
    end component;

    -- 8 bit register (PC Register)
    component reg_8bit is
        port(
            reset_bar, load_bar : in std_logic;
            clk : in std_logic;
            data_in : in std_logic_vector(7 downto 0);
            data_out : out std_logic_vector(7 downto 0)
            );
    end component;

    -- ------------------------------------------
    -- MAIN ALU SECTION

    -- 8+8 : PC Adder, ALU,  branch adder
    component ALU_8bit is
        port (   
            op : in std_logic_vector(3 downto 0);
            x : in std_logic_vector(7 downto 0);
            y : in std_logic_vector(7 downto 0);
            s : out std_logic_vector(7 downto 0);
            z : out std_logic;
            o_f : out std_logic
        );
    end component;

    -- ALU control unit
    component ALU_control is
        port (
            funct : in std_logic_vector(5 downto 0);
            ALU_op : in std_logic_vector(1 downto 0);
            ALU_cont : out std_logic_vector(3 downto 0)
        );
    end component;

    -- Sign Truncate
    component sign_truncate_16to8 is
        port (
            data_in : in std_logic_vector(15 downto 0);
            data_out : out std_logic_vector(7 downto 0)
        );
    end component;

    -- ------------------------------------------
    -- RAM
    -- Data Memory (256x8) (LPM_RAM_DQ function)
    component main_mem IS
        PORT
        (
            address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
            clock		: IN STD_LOGIC;
            data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
            wren		: IN STD_LOGIC ;
            q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
        );
    END component;

    -- ------------------------------------------
    -- OUTPUT MUX
    component mux_8bit_8x1 is
        port (
            sel : in std_logic_vector(2 downto 0);
            data_in0 : in std_logic_vector(7 downto 0);
            data_in1 : in std_logic_vector(7 downto 0);
            data_in2 : in std_logic_vector(7 downto 0);
            data_in3 : in std_logic_vector(7 downto 0);
            data_in4 : in std_logic_vector(7 downto 0);
            data_in5 : in std_logic_vector(7 downto 0);
            data_in6 : in std_logic_vector(7 downto 0);
            data_in7 : in std_logic_vector(7 downto 0);
            data_out : out std_logic_vector(7 downto 0)
        );
    end component;

begin
    -- component instantiations

    -- ------------------------------------------
    -- INSTRUCTION 
    -- Instruction Memory (32 bits, 256 instructions) (256x32) LPM_ROM function
    ROM : instr_mem port map (
        address => i_PC,
        clock => GClock,
        q => i_instructionOut
    );
    
    -- PC Adder
    PC_4_Adder : ALU_8bit port map (
        op => "0010",
        x => i_PC,
        y => "00000100",
        s => i_PC_plus4,
        z => open,
        o_f => open
    );

    -- PC Register 
    PC_register : reg_8bit port map (
        reset_bar => GReset, load_bar => '0',
        clk => GClock,
        data_in => i_PCReg_in,
        data_out => i_PC
    );

    -- ------------------------------------------
    -- CONTROL
    -- Control Unit
    controlUnit : ssp_control port map (
        instr => i_instructionOut(31 downto 26),
        RegDst => i_RegDst, ALUSrc => i_ALUSrc, MemtoReg => i_MemtoReg, RegWrite => i_RegWriteOut, 
        MemRead => i_MemRead, MemWrite => i_MemWriteOut, Branch => i_BranchOut, ALUOp1 => i_ALUOp1, ALUOp0 => i_ALUOp0, Jump => i_Jump
    );

    -- ------------------------------------------
    -- REGISTERS
    -- Register File (8x8bit registers)
    registerFile : register_file_8x8 port map (
        clk => GClock,
        reset_bar => GReset,
        read_reg1 => rs, read_reg2 => rt, write_reg => rd,
        write_data => i_WriteData,
        wr => i_RegWriteOut,
        read_data1 => i_ReadData1,
        read_data2 => i_ReadData2
    );

    -- Write Register Mux
    registerFileMUX : mux_5bit_2x1 port map (
        data_0 => i_instructionOut(20 downto 16), data_1 => i_instructionOut(15 downto 11),
        sel => i_RegDst,
        data_out => rd
    );

    -- ------------------------------------------
    -- MAIN ALU SECTION
    -- ALU
    ALU_main : ALU_8bit port map (
        op => i_ALU_cont,
        x => i_ReadData1,
        y => ALU_mux_out,
        s => i_ALUResult,
        z => i_ZeroOut,
        o_f => open
    );

    -- Sign Truncate
    sign_truncate : sign_truncate_16to8 port map (
        data_in => i_instructionOut(15 downto 0),
        data_out => sign_trunc_out
    );

    -- ALU MUX
    ALU_mux : mux_8bit_2x1 port map (
        data_0 => i_ReadData2, data_1 => sign_trunc_out,
        sel => i_ALUSrc,
        data_out => ALU_mux_out
    );

    -- ALU Control Unit
    ALUControl : ALU_control port map (
        funct => i_instructionOut(5 downto 0),
        ALU_op => i_ALUOp1 & i_ALUOp0,
        ALU_cont => i_ALU_cont
    );
    
    -- ------------------------------------------  
    -- BRANCH LOGIC
    -- Branch Adder 
    BranchAdder : ALU_8bit port map (
        op => "0010",
        x => i_PC_plus4,
        y => br_targ_offset,
        s => br_targ_addr,
        z => open,
        o_f => open
    );

    -- Branch MUX
    BranchMUX : mux_8bit_2x1 port map (
        data_0 => i_PC_plus4, data_1 => br_targ_addr,
        sel => br_control,
        data_out => br_result
    );

    -- Branch shift left
    br_targ_offset <= sign_trunc_out(5 downto 0) & "00";
    br_control <= i_BranchOut and i_ZeroOut;

    -- ------------------------------------------
    -- JUMP LOGIC
    -- Jump MUX
    JumpMUX : mux_8bit_2x1 port map (
        data_0 => br_result, data_1 => jmp_targ_addr,
        sel => i_Jump,
        data_out => i_PCReg_in
    );
    -- calculate jump target address : higher 4 bits of PC+4 + lower 26 bits of the instruction word shifted left by 2
    --jmp_targ_addr <= i_PC_plus4(7 downto 6) & i_instructionOut(3 downto 0) & "00";
	 
	 -- calculate jump target address : highest 6 bits of the address (instruction(5..0)) + "00"
	 jmp_targ_addr <=  i_instructionOut(5 downto 0) & "00";
    -- ------------------------------------------
    -- RAM SECTION
    -- Data Memory (256x8) (LPM_RAM_DQ function)
    RAM : main_mem port map (
        address => i_ALUResult,
        clock => GClock,
        data => i_ReadData2,
        wren => i_MemWriteOut,
        q => i_ram_read_data
    );

    -- Memory MUX
    MemoryMUX : mux_8bit_2x1 port map (
        data_0 => i_ALUResult, data_1 => i_ram_read_data,
        sel => i_MemtoReg,
        data_out => i_WriteData
    );

    -- ------------------------------------------
    -- OUTPUT MUX
    OutputMUX : mux_8bit_8x1 port map (
        sel => valueSelect,
        data_in0 => i_PC,
        data_in1 => i_ALUResult,
        data_in2 => i_ReadData1,
        data_in3 => i_ReadData2,
        data_in4 => i_WriteData,
        data_in5 => i_other,
        data_in6 => i_other,
        data_in7 => i_other,
        data_out => i_muxOut
    );


    
    -- concurrent signal connections
    i_other <= '0' & i_RegDst & i_Jump & i_MemRead & i_MemtoReg & i_ALUOp1 & i_ALUOp0 & i_ALUSrc;



    -- output driver

    muxOut <= i_muxOut;
    instructionOut <= i_instructionOut;
    BranchOut <= i_BranchOut;
    ZeroOut <= i_ZeroOut;
    MemWriteOut <= i_MemWriteOut;
    RegWriteOut <= i_RegWriteOut;



end structural;