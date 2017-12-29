#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

#include <arpa/inet.h>
#include <netinet/in.h>

int main(int argc, char *argv[])
{

int status, i, sockfd;
struct addrinfo hints;
struct addrinfo *servinfo, *p;  // will point to the results
char ipstr[INET6_ADDRSTRLEN];

memset((&hints), 0, sizeof(hints)); // make sure the struct is empty
hints.ai_family = AF_UNSPEC;     // don't care IPv4 or IPv6
hints.ai_socktype = SOCK_STREAM; // TCP stream sockets
hints.ai_flags = AI_PASSIVE;     // fill in my IP for me

if ((status = getaddrinfo(NULL, "22", &hints, &servinfo)) != 0) {
    fprintf(stderr, "getaddrinfo error: %s\n", gai_strerror(status));
    exit(1);
}

// servinfo now points to a linked list of 1 or more struct addrinfos

    // loop through all the results and connect to the first we can
    for(i = 0, p = servinfo; p != NULL; i++, p = p->ai_next) {
      void *addr;
      char *ipver;

        fprintf(stderr, "loop %d\n", i);
        fprintf(stderr, "family %d, socktype %d, protocol %d\n", p->ai_family, p->ai_socktype, p->ai_protocol);
        fprintf(stderr, "addrln %d, addr %p\n", p->ai_addrlen, p->ai_addr);

        // get the pointer to the address itself,
        // different fields in IPv4 and IPv6:
        if (p->ai_family == AF_INET) { // IPv4
            struct sockaddr_in *ipv4 = (struct sockaddr_in *)p->ai_addr;
            fprintf(stderr, "sin_len %d, sin_family %d, sin_port %d, sin_addr %d\n", ipv4->sin_len, 
            ipv4->sin_family, htons(ipv4->sin_port), ipv4->sin_addr.s_addr);
            addr = &(ipv4->sin_addr);
            ipver = "IPv4";
        } else { // IPv6
            struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)p->ai_addr;
            addr = &(ipv6->sin6_addr);
            ipver = "IPv6";
        }

        // convert the IP to a string and print it:
        inet_ntop(p->ai_family, addr, ipstr, sizeof ipstr);
        printf("  %s: %s\n", ipver, ipstr);

//        if ((sockfd = socket(p->ai_family, p->ai_socktype,
//                p->ai_protocol)) == -1) {
//            perror("client: socket");
//            //continue;
//        }

//        if (connect(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
//            //close(sockfd);
//            perror("client: connect");
//            continue;
//        }

    }

// ... do everything until you don't need servinfo anymore ....

freeaddrinfo(servinfo); // free the linked-list

}
