//
//  main.c
//  sntpos server
//
//  Created by Barney Hilken on 07/03/2024.
//

#include <stdio.h>
#include <sys/time.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>
#include <termios.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <sys/socket.h>


void dump(uint8_t bytes[48])
{
    for(int i=0;i<48;i++)
    {
        printf("%4.2X",bytes[i]);
        if (i%8 == 7)
            printf("\n");
    }
}

void dosntp(uint32_t queryBlock[12], uint32_t replyBlock[12])
{
    struct timeval now;
    uint32_t nowSec,nowFrac;

    gettimeofday(&now,NULL);
    nowSec = (uint32_t)now.tv_sec + 2208988800U;
    nowFrac = (uint32_t)now.tv_usec * 4295U;
    
    printf("Received data\n");
    dump((uint8_t *)queryBlock);
    
    replyBlock[0] = htonl(4<<27 | 4<<24 | 1<<16);
    replyBlock[1] = 0;
    replyBlock[2] = 0;
    replyBlock[3] = 0;
    replyBlock[4] = htonl(nowSec);
    replyBlock[5] = htonl(nowFrac);
    replyBlock[6] = queryBlock[10];
    replyBlock[7] = queryBlock[11];
    replyBlock[8] = htonl(nowSec);
    replyBlock[9] = htonl(nowFrac);
    
    gettimeofday(&now,NULL);
    nowSec = (uint32_t)now.tv_sec + 2208988800U;
    nowFrac = (uint32_t)now.tv_usec * 4295U;

    replyBlock[10] = htonl(nowSec);
    replyBlock[11] = htonl(nowFrac);
}

void ntpcomm(char* server, char* queryBlock, char* replyBlock)
{
    int sockNum;
    struct sockaddr_in server_addr;
    
    // Create socket:
    sockNum = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if(sockNum < 0)
    {
        printf("Can't create socket %d\n",errno);
        return;
    }
    
    // Set port and IP:
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(123);
    server_addr.sin_addr.s_addr = inet_addr(server);
    
    // Send the message to server:
    if(sendto(sockNum, queryBlock, 48, 0,
         (struct sockaddr*)&server_addr, sizeof(server_addr)) < 48)
    {
        printf("Unable to send query %d\n",errno);
        return;
    }
    
    // Receive the server's response:
    if(recvfrom(sockNum, replyBlock, 48, 0, NULL, 0) < 48){
        printf("Unable to receive reply %d\n", errno);
        return;
    }
    
    // Close the socket:
    close(sockNum);
return;
}

int main(int argc, char * argv[])
{
    
    int serial;
    struct termios terminal;
    char *server = NULL;
    char opt;
    int baud = 0;

    while((opt = getopt(argc, argv, "s:b:")) != -1)
        switch(opt)
        {
            case 's':
            {
                server = optarg;
                break;
            }
            case 'b':
            {
                baud = atoi(optarg);
                break;
            }
        }
    serial = open(argv[optind], O_RDWR | O_NOCTTY | O_NDELAY);
    if (serial == -1) return -1;
    tcflush(serial, TCIOFLUSH);

    tcgetattr(serial, &terminal);
    terminal.c_cflag |= CLOCAL | CREAD | CRTSCTS;
    terminal.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    terminal.c_oflag &= ~OPOST;
    if (baud > 0)
        cfsetspeed(&terminal, baud);
    tcsetattr(serial, TCSANOW, &terminal);
    fcntl(serial,F_SETFL,0);
    
    while(1)
    {
        char queryBlock[48],replyBlock[48];
        int count = 0;
        
        printf("Awaiting query\n");
        do
        {
            ssize_t chars = read(serial,queryBlock+count,48-count);
            if (chars == -1) return -2;
            count += chars;
        }
        while (count < 48);
        
        if (server)
            ntpcomm(server, queryBlock, replyBlock);
        else
            dosntp((uint32_t *)queryBlock, (uint32_t *)replyBlock);
        
        if(write(serial,replyBlock,48) != 48)
            return(-3);
        printf("Reply sent\n");
        dump((uint8_t *)replyBlock);
    }
    return 0;
}

