----------------------------------------------------------------------------------
--Engineer: Mustafa Haluk Yaldız
--Module Name: range_window
--Target Devices: Pnyq-Z2 
--Tool Versions: Vivado 2025.2
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.hann_coeff_pkg.all;

entity range_window is
    port(
        aclk            : in    STD_LOGIC;
        aresetn         : in    STD_LOGIC;

        s_axis_tdata    : in    STD_LOGIC_VECTOR(31 downto 0);
        s_axis_tvalid   : in    STD_LOGIC;
        s_axis_tready   : out    STD_LOGIC;
        s_axis_tlast    : in   STD_LOGIC;

        m_axis_tdata    : out   STD_LOGIC_VECTOR(31 downto 0);
        m_axis_tvalid   : out   STD_LOGIC;
        m_axis_tready   : in    STD_LOGIC;
        m_axis_tlast    : out   STD_LOGIC
    );
end entity range_window;

architecture RTL of range_window is

    subtype sample_t  is signed(15 downto 0);
    subtype product_t is signed(32 downto 0);
    
    signal sample_index : unsigned(7 downto 0);
    signal advance      : STD_LOGIC;
    
    -- Aşama 1: Giriş örnekleri ve örneğe ait katsayı
    signal i_s1     : sample_t;
    signal q_s1     : sample_t;
    signal coeff_s1 : signed(16 downto 0);
    signal valid_s1 : STD_LOGIC;
    signal last_s1  : STD_LOGIC;
    
    -- Aşama 2: Çarpım sonuçları
    signal i_product_s2 : product_t;
    signal q_product_s2 : product_t;
    signal valid_s2     : STD_LOGIC;
    signal last_s2       : STD_LOGIC;
    
    -- Aşama 3: Yuvarlanmış ve paketlenmiş çıkış
    signal data_s3  : STD_LOGIC_VECTOR(31 downto 0);
    signal valid_s3 : STD_LOGIC;
    signal last_s3  : STD_LOGIC;
    
    -- En yakın tamsayıya yuvarlama; tam yarım değerlerde sıfırdan uzaklaşma
    function round_product(
        product : product_t
    ) return sample_t is
    
        variable magnitude : unsigned(32 downto 0);
        variable rounded   : product_t;
        
    begin
        if (product < 0) then
            magnitude := unsigned(-product);
        else
            magnitude := unsigned(product);
        end if;
        
        magnitude := magnitude + to_unsigned(16384, 33);
        rounded   := signed(shift_right(magnitude, 15));
        
        if(product < 0) then
            rounded := -rounded;
        end if;
        
        return resize(rounded, 16);
    end function;
begin
    -- Çıkış boşsa veya teslim edilecekse pipeline ilerler
    advance <= aresetn AND ((NOT valid_s3) OR m_axis_tready);
    
    s_axis_tready <= advance;
    
    m_axis_tdata  <= data_s3;
    m_axis_tvalid <= valid_s3;
    m_axis_tlast  <= last_s3;
    
    process(aclk)
        begin
            if rising_edge(aclk) then
                -- Aktif low, senkron reset
                if aresetn = '0' then
                    sample_index <= (others => '0');
                    
                    i_s1        <= (others => '0');
                    q_s1        <= (others => '0');
                    coeff_s1    <= (others => '0');
                    valid_s1    <= '0';
                    last_s1     <= '0';
                    
                    i_product_s2 <= (others => '0');
                    q_product_s2 <= (others => '0');
                    valid_s2     <= '0';
                    last_s2      <= '0';
                    
                    data_s3  <= (others => '0');
                    valid_s3 <= '0';
                    last_s3  <= '0';
                    
                elsif advance = '1' then
                
                    -- Aşama 1: Yeni giriş ve katsayı
                    valid_s1 <= s_axis_tvalid;
                    
                    if s_axis_tvalid = '1' then
                        i_s1 <= signed(s_axis_tdata(15 downto 0));
                        q_s1 <= signed(s_axis_tdata(31 downto 16));
                        
                        coeff_s1 <= signed('0' & hann_coeff(sample_index));
                        
                        last_s1 <= s_axis_tlast;
                        
                        -- Sadece kabul edilen örneklerde ilerleme
                        if sample_index = to_unsigned(255, 8) then
                            sample_index <= (others => '0');
                        else
                            sample_index <= sample_index + 1;
                        end if;
                    end if;
                    
                    -- Aşama 2: Önceki aşamanın örneklerini çarp
                    valid_s2 <= valid_s1;
                    last_s2  <= last_s1;
                    
                    i_product_s2 <= i_s1 * coeff_s1;
                    q_product_s2 <= q_s1 * coeff_s1;
                    
                    -- Aşama 3: Çarpım sonuçlarını yuvarlama
                    valid_s3 <= valid_s2;
                    last_s3  <= last_s2;
                    
                    data_s3 <= 
                        STD_LOGIC_VECTOR(round_product(q_product_s2)) &
                        STD_LOGIC_VECTOR(round_product(i_product_s2));
                end if;
            end if;
    end process;
    
end architecture RTL;
