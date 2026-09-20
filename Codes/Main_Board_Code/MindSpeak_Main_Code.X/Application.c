#include "Application.h"
#include "peripheral/spi/spi_master/plib_spi1_master.h"











int main(){

    SPI1_Initialize();




    while(1){
    
    SPI1_Write("Moatasem", 9);
    SPI1_Write("Omar", 5);
    
    
    
    
    }





}