----------------------------------------------------------------------------------
--Engineer: Mustafa Haluk Yaldız
--Module Name: axis_transaction
--Target Devices: Pnyq-Z2 
--Tool Versions: Vivado 2025.2
----------------------------------------------------------------------------------
     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity axis_register_slice is
  Port (aclk            : IN  STD_LOGIC;
        aresetn         : IN  STD_LOGIC;
     
        s_axis_tdata    : IN  STD_LOGIC_VECTOR(31 downto 0);
        s_axis_tvalid   : IN  STD_LOGIC;
        s_axis_tready   : OUT STD_LOGIC;
        s_axis_tlast    : IN  STD_LOGIC;
     
        m_axis_tdata    : OUT STD_LOGIC_VECTOR(31 downto 0);
        m_axis_tvalid   : OUT STD_LOGIC;
        m_axis_tready   : IN  STD_LOGIC;
        m_axis_tlast    : OUT STD_LOGIC
        );
end axis_register_slice;

architecture Behavioral of axis_register_slice is

signal SRC_data_reg     : STD_LOGIC_VECTOR(31 downto 0);  
signal SRC_last_reg     : STD_LOGIC;                      
signal SRC_ready_buff   : STD_LOGIC;                      

signal BufferFull       : STD_LOGIC;

signal i_sample : signed(15 downto 0);
signal q_sample : signed(15 downto 0);

begin

i_sample <= signed(SRC_data_reg(31 downto 16));
q_sample <= signed(SRC_data_reg(15 downto 0));

TRANSFER_Register_Slice : process(aclk, aresetn)

    begin

        if(aresetn = '0') then                                                                                                          
            SRC_data_reg <= (others => '0');                                    
            BufferFull <= '0';                                                  
            SRC_last_reg  <= '0';                                               
        elsif(rising_edge(aclk)) then                                           
            if SRC_ready_buff = '1' AND s_axis_tvalid = '1' then
                SRC_data_reg <= s_axis_tdata;
                SRC_last_reg <= s_axis_tlast;
                BufferFull <= '1';
            
            elsif m_axis_tready = '1' AND BufferFull = '1' then
                BufferFull <= '0';
            end if;
        end if;
    end process;
    SRC_ready_buff <= aresetn AND ((NOT BufferFull) OR m_axis_tready);
    s_axis_tready   <= SRC_ready_buff;
    m_axis_tdata    <= SRC_data_reg;                    
    m_axis_tlast    <= SRC_last_reg;
    m_axis_tvalid   <= BufferFull;
end Behavioral;
