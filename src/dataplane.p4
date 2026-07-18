/* -*- P4_16 -*- */
/*
 * dataplane.p4  -  CN HW3 P4 Data Plane project
 * Target      : v1model / BMv2 simple_switch
 *
 * Pipeline (ingress):
 *   parse (Ethernet, IPv4, TCP/UDP/ICMP)
 *     -> sec_policy   (ternary firewall in the data plane)
 *     -> classify     (ternary; result carried in metadata)
 *     -> qos_mark     (exact class_id -> DSCP)
 *     -> ttl check    (drop expired)
 *     -> ipv4_lpm     (LPM forward + MAC rewrite + TTL--)
 *   deparse + IPv4 checksum recompute
 *
 * Design notes are in report.pdf (section "pipeline design").
 * NOTE: nothing here is a routing protocol; tables are filled with static
 * entries by the control plane (see src/s1-commands.txt).
 */

#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x0800;
const bit<8>  PROTO_ICMP = 1;
const bit<8>  PROTO_TCP  = 6;
const bit<8>  PROTO_UDP  = 17;

/*************************************************************************
******************** H E A D E R S  ************************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<6>    dscp;        // DiffServ Code Point (top 6 bits of the ToS byte)
    bit<2>    ecn;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<3>  res;
    bit<9>  flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

header udp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> length_;
    bit<16> checksum;
}

header icmp_t {
    bit<8>  type_;
    bit<8>  code;
    bit<16> checksum;
}

/* metadata carries the classification result between stages */
struct metadata {
    bit<8>  class_id;     // 1=Interactive 2=Web 3=UDPservice 4=Other
    bit<1>  drop_flag;    // set by drop_pkt() so later stages are skipped
    bit<16> l4_dst;       // L4 destination port (TCP or UDP), 0 otherwise
    bit<16> l4_src;       // L4 source port
}

struct headers {
    ethernet_t ethernet;
    ipv4_t     ipv4;
    tcp_t      tcp;
    udp_t      udp;
    icmp_t     icmp;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        meta.class_id  = 0;
        meta.drop_flag = 0;
        meta.l4_dst    = 0;
        meta.l4_src    = 0;
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;
            default:   accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            PROTO_TCP:  parse_tcp;
            PROTO_UDP:  parse_udp;
            PROTO_ICMP: parse_icmp;
            default:    accept;
        }
    }

    state parse_tcp {
        packet.extract(hdr.tcp);
        meta.l4_src = hdr.tcp.srcPort;
        meta.l4_dst = hdr.tcp.dstPort;
        transition accept;
    }

    state parse_udp {
        packet.extract(hdr.udp);
        meta.l4_src = hdr.udp.srcPort;
        meta.l4_dst = hdr.udp.dstPort;
        transition accept;
    }

    state parse_icmp {
        packet.extract(hdr.icmp);
        transition accept;
    }
}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {
        verify_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.dscp, hdr.ipv4.ecn,
              hdr.ipv4.totalLen, hdr.ipv4.identification, hdr.ipv4.flags,
              hdr.ipv4.fragOffset, hdr.ipv4.ttl, hdr.ipv4.protocol,
              hdr.ipv4.srcAddr, hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   ******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    /* ---- shared actions ---- */
    action drop_pkt() {
        mark_to_drop(standard_metadata);
        meta.drop_flag = 1;
    }
    action allow() { /* NoAction - fall through */ }

    /* ---- (4) SECURITY POLICY : ternary firewall ---- */
    table sec_policy {
        key = {
            hdr.ipv4.srcAddr : ternary;
            hdr.ipv4.dstAddr : ternary;
        }
        actions = { drop_pkt; allow; }
        size = 64;
        default_action = allow();   // anything not matched is allowed
    }

    /* ---- (2) CLASSIFICATION : ternary, result -> metadata ---- */
    action set_class(bit<8> c) { meta.class_id = c; }
    table classify {
        key = {
            hdr.ipv4.protocol : ternary;
            meta.l4_dst        : ternary;
        }
        actions = { set_class; }
        size = 64;
        default_action = set_class(4);   // Other/Bulk
    }

    /* ---- (3) QoS MARKING : exact class_id -> DSCP ---- */
    action set_dscp(bit<6> d) { hdr.ipv4.dscp = d; }
    table qos_mark {
        key = { meta.class_id : exact; }
        actions = { set_dscp; NoAction; }
        size = 8;
        default_action = NoAction();
    }

    /* ---- (1) FORWARDING : LPM on dst IPv4 ---- */
    action ipv4_forward(macAddr_t dstMac, egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;  // switch port MAC
        hdr.ethernet.dstAddr = dstMac;                // next hop / host MAC
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;              // decrement TTL
    }
    table ipv4_lpm {
        key = { hdr.ipv4.dstAddr : lpm; }
        actions = { ipv4_forward; drop_pkt; }
        size = 256;
        default_action = drop_pkt();   // unknown destination -> documented drop
    }

    apply {
        if (hdr.ipv4.isValid()) {
            // 1) firewall first: drop forbidden traffic before doing any work
            sec_policy.apply();

            if (meta.drop_flag == 0) {
                // 2) classify, then 3) mark DSCP by class
                classify.apply();
                qos_mark.apply();

                // 4) TTL: if it would expire, drop (would punt ICMP TimeExceeded
                //    to the control plane on real HW); else forward via LPM.
                if (hdr.ipv4.ttl <= 1) {
                    drop_pkt();
                } else {
                    ipv4_lpm.apply();
                }
            }
        }
        // non-IPv4 traffic is left unmatched (dropped by BMv2 default)
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   ******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        // TTL and DSCP were modified -> recompute the IPv4 header checksum
        update_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.dscp, hdr.ipv4.ecn,
              hdr.ipv4.totalLen, hdr.ipv4.identification, hdr.ipv4.flags,
              hdr.ipv4.fragOffset, hdr.ipv4.ttl, hdr.ipv4.protocol,
              hdr.ipv4.srcAddr, hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  D E P A R S E R  ******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
        packet.emit(hdr.udp);
        packet.emit(hdr.icmp);
    }
}

/*************************************************************************
***********************  S W I T C H  **********************************
*************************************************************************/

V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;
