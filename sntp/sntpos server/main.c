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
#include <netdb.h>

#define LIVM(block) ((uint8_t *)block)[0]
#define Stratum(block) ((uint8_t *)block)[1]
#define Poll(block) ((uint8_t *)block)[2]
#define Precision(block) ((uint8_t *)block)[3]
#define RootDelay(block) ((uint32_t *)block)[1]
#define RootDisp(block) ((uint32_t *)block)[2]
#define RefID(block) ((uint32_t *)block)[3]
#define RefTime(block) ((uint64_t *)block)[2]
#define OrgTime(block) ((uint64_t *)block)[3]
#define RecvTime(block) ((uint64_t *)block)[4]
#define XmtTime(block) ((uint64_t *)block)[5]



uint64_t getNtpTime()
{
    struct timeval now;
    uint32_t sec,frac;
    
    gettimeofday(&now,NULL);
    sec = (uint32_t)now.tv_sec + 2208988800U;
    frac = (uint32_t)now.tv_usec * 4295U;
    return (uint64_t)sec << 32 | (uint64_t)frac;
}

void dump(uint8_t bytes[48])
{
    for(int i=0;i<48;i++)
    {
        fprintf(stderr, "%4.2X",bytes[i]);
        if (i%8 == 7)
            fprintf(stderr, "\n");
    }
}

int64_t sntp(char* server, uint8_t replyBlock[48])
{
    uint64_t sendTime, dstTime;
    uint8_t queryBlock[48] = {0};
    int sockNum;
    struct addrinfo hints, *address;
    uint64_t correction;
    int error;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = PF_UNSPEC;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = IPPROTO_UDP;

    // look up server IP address
    error = getaddrinfo(server, "123", &hints, &address);
    if (error)
    {
        fprintf(stderr, "Can't find server %d\n", error);
        return INT64_MIN;
    }

    // Create socket:
    sockNum = socket(address->ai_family, SOCK_DGRAM, IPPROTO_UDP);
    if(sockNum < 0)
    {
        fprintf(stderr, "Can't create socket %d\n",errno);
        return INT64_MIN;
    }
    
    // set up query block
    sendTime = getNtpTime();
    LIVM(queryBlock) = 4<<3 | 3;                    // LI = 0, VN = 4, Mode = 3
    XmtTime(queryBlock) = htonll(sendTime);

    // Send the message to server:
    if(sendto(sockNum, queryBlock, 48, 0,
              address->ai_addr, address->ai_addrlen) < 48)
    {
        fprintf(stderr, "Unable to send query %d\n",errno);
        return INT64_MIN;
    }
    
    // Receive the server's response:
    if(recvfrom(sockNum, replyBlock, 48, 0, NULL, 0) < 48){
        fprintf(stderr, "Unable to receive reply %d\n", errno);
        return INT64_MIN;
    }
    
    // remember receive time
    dstTime = getNtpTime();
    
    // Close the socket:
    close(sockNum);
    freeaddrinfo(address);
    
    correction = (ntohll(RecvTime(replyBlock)) - sendTime) - (dstTime - ntohll(XmtTime(replyBlock)));
    Stratum(replyBlock) += 1;                           // increment stratum
    RefTime(replyBlock) = htonll(dstTime + correction);     // set reference time to now
    return correction;
}

int main(int argc, char * argv[])
{
    
    int serial;
    struct termios terminal;
    char *server = "pool.ntp.org";
    char opt;
    int baud = 9600;
    uint8_t stateBlock[48];
    int64_t correction;
#ifdef DEBUG
    int debug = 2;
#else
    int debug = 0;
#endif

    while((opt = getopt(argc, argv, "s:b:d:")) != -1)
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
            case 'd':
            {
                debug = atoi(optarg);
                break;
            }
        }

    if (!argv[optind])
    {
        fprintf(stderr, "Usage: %s [-sbd] <tty>\n",argv[0]);
        return -1;
    }

    correction = sntp(server, stateBlock);
    if (correction == INT64_MIN)
        return -1;
    
    if (debug)
    {
        fprintf(stderr, "Received state data\n");
        if (debug>=2) dump(stateBlock);
        fprintf(stderr, "Correction %f\n", correction / 4.2949673E9);
    }

    
    serial = open(argv[optind], O_RDWR | O_NOCTTY | O_NDELAY);
    if (serial == -1) return -1;
    tcflush(serial, TCIOFLUSH);

    tcgetattr(serial, &terminal);
    terminal.c_cflag |= CLOCAL | CREAD; // | CRTSCTS;
    terminal.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    terminal.c_oflag &= ~OPOST;
    cfsetspeed(&terminal, baud);
    tcsetattr(serial, TCSANOW, &terminal);
    fcntl(serial,F_SETFL,0);
    
    while(1)
    {
        uint8_t queryBlock[48],replyBlock[48];
        int count = 0;
        uint64_t dstTime;
        
        if (debug) fprintf(stderr, "Awaiting query\n");
        do
        {
            ssize_t chars = read(serial,queryBlock+count,48-count);
            if (chars == -1) return -2;
            count += chars;
        }
        while (count < 48);
        dstTime = getNtpTime() + correction;
        
        if (debug)
        {
            fprintf(stderr, "Received query data\n");
            if (debug>=2) dump((uint8_t *)queryBlock);
        }
        
        // calculate reply
        
        memcpy(replyBlock,stateBlock,24);
        OrgTime(replyBlock) = XmtTime(queryBlock);
        RecvTime(replyBlock) = htonll(dstTime + correction);
        XmtTime(replyBlock) = htonll(getNtpTime() + correction);

        if(write(serial,replyBlock,48) != 48)
            return(-3);
 
        if (debug)
        {
            fprintf(stderr, "Reply sent\n");
            if (debug >= 2) dump(replyBlock);
        }
    }
    return 0;
}

