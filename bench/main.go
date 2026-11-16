// Synthetic load for comparing webproxy servers. Every server speaks the same
// websocket protocol, so one client drives any of them.
//
//	bench auth -addr 127.0.0.1:18443 -ca ca.pem   a mock HTTPS auth service
//	bench load -url ws://127.0.0.1:18080/ws       the scenarios, one line each
package main

import (
	"bufio"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha1"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"encoding/pem"
	"errors"
	"flag"
	"fmt"
	"io"
	"math/big"
	"net"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: bench auth|load [flags]")
		os.Exit(2)
	}
	switch os.Args[1] {
	case "auth":
		runAuth(os.Args[2:])
	case "load":
		runLoad(os.Args[2:])
	default:
		fmt.Fprintln(os.Stderr, "usage: bench auth|load [flags]")
		os.Exit(2)
	}
}

// --- mock auth ---------------------------------------------------------------

// A token `<user>@<org>` is that user in that organization, a SysAdmin when the
// user's name starts with `admin`; anything else is 401.
func runAuth(args []string) {
	fs := flag.NewFlagSet("auth", flag.ExitOnError)
	addr := fs.String("addr", "127.0.0.1:18443", "listen address")
	caPath := fs.String("ca", "ca.pem", "where to write the CA certificate")
	fs.Parse(args)

	cert, caPEM := certificates()
	if err := os.WriteFile(*caPath, caPEM, 0o644); err != nil {
		panic(err)
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user, org, ok := strings.Cut(r.Header.Get("Authorization"), "@")
		if !ok || user == "" || org == "" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"id":              user,
			"displayName":     user + "@example.com",
			"organization_id": org,
			"scopes":          []string{"read", "write"},
			"isAdmin":         strings.HasPrefix(user, "admin"),
		})
	})
	server := &http.Server{Addr: *addr, Handler: handler, TLSConfig: &tls.Config{Certificates: []tls.Certificate{cert}}}
	fmt.Println("auth listening on", *addr)
	panic(server.ListenAndServeTLS("", ""))
}

// A throwaway CA and a 127.0.0.1 leaf signed by it.
func certificates() (tls.Certificate, []byte) {
	caKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	ca := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{CommonName: "bench CA"},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().Add(24 * time.Hour),
		IsCA:                  true,
		KeyUsage:              x509.KeyUsageCertSign,
		BasicConstraintsValid: true,
	}
	caDER, err := x509.CreateCertificate(rand.Reader, ca, ca, &caKey.PublicKey, caKey)
	if err != nil {
		panic(err)
	}

	leafKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	leaf := &x509.Certificate{
		SerialNumber: big.NewInt(2),
		Subject:      pkix.Name{CommonName: "127.0.0.1"},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(24 * time.Hour),
		KeyUsage:     x509.KeyUsageDigitalSignature,
		ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		IPAddresses:  []net.IP{net.ParseIP("127.0.0.1")},
	}
	leafDER, err := x509.CreateCertificate(rand.Reader, leaf, ca, &leafKey.PublicKey, caKey)
	if err != nil {
		panic(err)
	}
	return tls.Certificate{Certificate: [][]byte{leafDER, caDER}, PrivateKey: leafKey},
		pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: caDER})
}

// --- load --------------------------------------------------------------------

type result struct {
	name      string
	latencies []time.Duration
	errors    int
	elapsed   time.Duration
}

func (r result) print() {
	sort.Slice(r.latencies, func(i, j int) bool { return r.latencies[i] < r.latencies[j] })
	pct := func(p float64) float64 {
		if len(r.latencies) == 0 {
			return 0
		}
		return float64(r.latencies[int(p*float64(len(r.latencies)-1))].Microseconds()) / 1000
	}
	fmt.Printf("%-22s ops=%-8d ops/s=%-8.0f p50=%6.2fms  p99=%6.2fms  max=%7.2fms  errors=%d\n",
		r.name, len(r.latencies), float64(len(r.latencies))/r.elapsed.Seconds(), pct(0.50), pct(0.99), pct(1), r.errors)
}

func runLoad(args []string) {
	fs := flag.NewFlagSet("load", flag.ExitOnError)
	wsURL := fs.String("url", "ws://127.0.0.1:18080/ws", "websocket endpoint")
	clients := fs.Int("clients", 200, "connections")
	clusterSize := fs.Int("cluster", 10, "connections per cluster")
	duration := fs.Duration("duration", 10*time.Second, "how long each timed scenario runs")
	only := fs.String("only", "", "run just this timed scenario: ping, request/provide or request")
	activeCount := fs.Int("active", 0, "connections that run the timed scenarios, spread over the clusters; the rest stay connected and idle (0 = all)")
	fs.Parse(args)

	// Fresh users every run, so the first subscribe always reaches the auth service.
	run := strconv.FormatInt(time.Now().UnixNano(), 36)
	tokens := make([]string, *clients)
	for i := range tokens {
		tokens[i] = fmt.Sprintf("u%s-%d@org%s-%d", run, i, run, i / *clusterSize)
	}

	conns, res := subscribeAll(*wsURL, tokens, "subscribe (auth call)")
	res.print()
	closeAll(conns)
	if *clusterSize > 1 && len(tokens) > 1 {
		settle(*wsURL, tokens[0], tokens[1], *clusterSize, len(conns))
	}

	conns, res = subscribeAll(*wsURL, tokens, "subscribe (cached)")
	res.print()
	defer closeAll(conns)
	if res.errors > 0 {
		fmt.Println("some connections failed to subscribe; skipping the timed scenarios")
		return
	}

	// The connections that take part, by their index among all of them.
	active := make([]int, len(conns))
	for i := range active {
		active[i] = i
	}
	if *activeCount > 0 && *activeCount < len(conns) {
		active = active[:*activeCount]
		for k := range active {
			active[k] = k * len(conns) / *activeCount
		}
	}
	pong := func(m string) bool { return m == "pong" }

	if *only == "" || *only == "ping" {
		timed("ping", conns, active, *duration, func(c *client, _ int, _ int) error {
			return c.roundTrip("ping", pong)
		}).print()
	}

	for i, c := range conns {
		c.serveRequests(i, *clusterSize)
	}
	if *only == "" || *only == "request/provide" {
		timed("request/provide", conns, active, *duration, func(c *client, i int, seq int) error {
			name := fmt.Sprintf("res-%d-%d", i, seq)
			return c.roundTrip("/r "+name, func(m string) bool { return strings.HasPrefix(m, "/p "+name+" ") })
		}).print()
	}

	// A cache miss: the peers are asked and none of them answers. The server
	// takes a connection's messages in order, so the pong says the request
	// before it was handled.
	if *only == "" || *only == "request" {
		timed("request (unprovided)", conns, active, *duration, func(c *client, i int, seq int) error {
			if err := c.write(0x1, []byte(fmt.Sprintf("/r miss:%d:%d", i, seq))); err != nil {
				return err
			}
			return c.roundTrip("ping", pong)
		}).print()
	}
}

func subscribeAll(wsURL string, tokens []string, name string) ([]*client, result) {
	conns := make([]*client, len(tokens))
	lat := make([]time.Duration, len(tokens))
	errs := make([]error, len(tokens))
	start := time.Now()
	var wg sync.WaitGroup
	// A thousand connections open at a time: more than a listener's backlog
	// holds are refused before the server ever sees them.
	opening := make(chan struct{}, 1000)
	for i, token := range tokens {
		wg.Add(1)
		opening <- struct{}{}
		go func() {
			defer wg.Done()
			defer func() { <-opening }()
			began := time.Now()
			c, err := dial(wsURL, "10.0.0.1", i)
			if err == nil {
				err = c.roundTrip("/s "+token, func(m string) bool { return m == "subscribed" })
			}
			conns[i], lat[i], errs[i] = c, time.Since(began), err
		}()
	}
	wg.Wait()
	res := result{name: name, elapsed: time.Since(start)}
	for i, err := range errs {
		if err != nil {
			res.errors++
			if res.errors == 1 {
				fmt.Fprintln(os.Stderr, "first error:", err)
			}
			continue
		}
		res.latencies = append(res.latencies, lat[i])
	}
	return conns, res
}

// Runs `op` back to back on every active connection at once for `d`.
func timed(name string, conns []*client, active []int, d time.Duration, op func(c *client, i int, seq int) error) result {
	var mu sync.Mutex
	res := result{name: name}
	deadline := time.Now().Add(d)
	start := time.Now()
	var wg sync.WaitGroup
	for _, i := range active {
		c := conns[i]
		wg.Add(1)
		go func() {
			defer wg.Done()
			var local []time.Duration
			failed := 0
			for seq := 0; time.Now().Before(deadline); seq++ {
				began := time.Now()
				if err := op(c, i, seq); err != nil {
					failed++
					continue
				}
				local = append(local, time.Since(began))
			}
			mu.Lock()
			res.latencies = append(res.latencies, local...)
			res.errors += failed
			mu.Unlock()
		}()
	}
	wg.Wait()
	res.elapsed = time.Since(start)
	return res
}

// Waits for the server to work through a mass disconnection, and says how long
// that took. Two newcomers of one cluster subscribe and pass a resource between
// them, which queues behind the closes everywhere the server keeps a
// connection, so it is through them once that is answered at once several
// times in a row.
func settle(wsURL string, requester string, provider string, clusterSize int, closed int) {
	began := time.Now()
	for prompt := 0; prompt < 5; {
		asked := time.Now()
		if exchange(wsURL, requester, provider, clusterSize) == nil && time.Since(asked) < 50*time.Millisecond {
			prompt++
		} else {
			prompt = 0
		}
	}
	fmt.Printf("%-22s %d closed at once; the server was through them %.2fs later\n", "disconnect", closed, time.Since(began).Seconds())
}

// One request provided between the first two connections of a cluster.
func exchange(wsURL string, requester string, provider string, clusterSize int) error {
	subscribed := func(m string) bool { return m == "subscribed" }
	a, err := dial(wsURL, "10.0.0.1", 0)
	if err != nil {
		return err
	}
	defer a.close()
	b, err := dial(wsURL, "10.0.0.1", 0)
	if err != nil {
		return err
	}
	defer b.close()
	if err := a.roundTrip("/s "+requester, subscribed); err != nil {
		return err
	}
	if err := b.roundTrip("/s "+provider, subscribed); err != nil {
		return err
	}
	b.serveRequests(1, clusterSize)
	return a.roundTrip("/r res-0-settle", func(m string) bool { return strings.HasPrefix(m, "/p res-0-settle ") })
}

func closeAll(conns []*client) {
	for _, c := range conns {
		if c != nil {
			c.close()
		}
	}
	time.Sleep(500 * time.Millisecond) // let the server run its close handlers
}

// --- a minimal websocket client ---------------------------------------------

type client struct {
	conn    net.Conn
	writeMu sync.Mutex
	inbox   chan string
	mu      sync.Mutex
	// Answers petitions from peers once set, see serveRequests.
	responder func(string)
}

// `index` is the connection's place among all of them. One address has some
// 28,000 ports to dial from, so every 20,000 connections dial from the next
// loopback address, which Linux answers on without being told: past the first
// 20,000 the server has to be on this machine.
func dial(wsURL string, forwardedFor string, index int) (*client, error) {
	u, err := url.Parse(wsURL)
	if err != nil {
		return nil, err
	}
	dialer := net.Dialer{Timeout: 5 * time.Second}
	if index >= 20000 {
		dialer.LocalAddr = &net.TCPAddr{IP: net.IPv4(127, 0, 0, byte(1+index/20000))}
	}
	conn, err := dialer.Dial("tcp", u.Host)
	if err != nil {
		return nil, err
	}
	var nonce [16]byte
	rand.Read(nonce[:])
	key := base64.StdEncoding.EncodeToString(nonce[:])
	fmt.Fprintf(conn, "GET %s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"+
		"Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\nX-Forwarded-For: %s\r\n\r\n",
		u.RequestURI(), u.Host, key, forwardedFor)
	reader := bufio.NewReader(conn)
	resp, err := http.ReadResponse(reader, nil)
	if err != nil {
		conn.Close()
		return nil, err
	}
	sum := sha1.Sum([]byte(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
	if resp.StatusCode != http.StatusSwitchingProtocols || resp.Header.Get("Sec-WebSocket-Accept") != base64.StdEncoding.EncodeToString(sum[:]) {
		conn.Close()
		return nil, fmt.Errorf("handshake answered %s", resp.Status)
	}
	c := &client{conn: conn, inbox: make(chan string, 64)}
	go c.read(reader)
	return c, nil
}

func (c *client) read(r *bufio.Reader) {
	defer close(c.inbox)
	for {
		var head [2]byte
		if _, err := io.ReadFull(r, head[:]); err != nil {
			return
		}
		opcode := head[0] & 0x0F
		size := uint64(head[1] & 0x7F)
		switch size {
		case 126:
			var ext [2]byte
			if _, err := io.ReadFull(r, ext[:]); err != nil {
				return
			}
			size = uint64(binary.BigEndian.Uint16(ext[:]))
		case 127:
			var ext [8]byte
			if _, err := io.ReadFull(r, ext[:]); err != nil {
				return
			}
			size = binary.BigEndian.Uint64(ext[:])
		}
		payload := make([]byte, size)
		if _, err := io.ReadFull(r, payload); err != nil {
			return
		}
		switch opcode {
		case 0x1:
			text := string(payload)
			c.mu.Lock()
			responder := c.responder
			c.mu.Unlock()
			if responder != nil && strings.HasPrefix(text, "/r ") {
				responder(text)
				continue
			}
			c.inbox <- text
		case 0x8:
			return
		case 0x9:
			c.write(0xA, payload)
		}
	}
}

func (c *client) write(opcode byte, payload []byte) error {
	frame := []byte{0x80 | opcode}
	switch n := len(payload); {
	case n < 126:
		frame = append(frame, 0x80|byte(n))
	case n < 1<<16:
		frame = append(frame, 0x80|126, byte(n>>8), byte(n))
	default:
		frame = append(frame, 0x80|127)
		frame = binary.BigEndian.AppendUint64(frame, uint64(n))
	}
	var mask [4]byte
	rand.Read(mask[:])
	frame = append(frame, mask[:]...)
	for i, b := range payload {
		frame = append(frame, b^mask[i%4])
	}
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_, err := c.conn.Write(frame)
	return err
}

// Sends `text` and waits for the first message `done` accepts.
func (c *client) roundTrip(text string, done func(string) bool) error {
	if err := c.write(0x1, []byte(text)); err != nil {
		return err
	}
	timeout := time.After(5 * time.Second)
	for {
		select {
		case m, ok := <-c.inbox:
			if !ok {
				return errors.New("connection closed")
			}
			if done(m) {
				return nil
			}
		case <-timeout:
			return errors.New("timed out waiting for an answer to " + text)
		}
	}
}

// Answers the petitions addressed to this connection: a request named
// `res-<requester>-<seq>` is answered by the next connection in the requester's
// cluster, so every request is provided exactly once.
func (c *client) serveRequests(me int, clusterSize int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.responder = func(text string) {
		var petition struct {
			ResourceID   string `json:"resourceId"`
			ResourceName string `json:"resourceName"`
		}
		if json.Unmarshal([]byte(strings.TrimPrefix(text, "/r ")), &petition) != nil {
			return
		}
		parts := strings.Split(petition.ResourceName, "-")
		if len(parts) != 3 {
			return
		}
		requester, _ := strconv.Atoi(parts[1])
		base := requester / clusterSize * clusterSize
		if base+(requester-base+1)%clusterSize == me {
			c.write(0x1, []byte("/p "+petition.ResourceID+` {"cached":true}`))
		}
	}
}

func (c *client) close() {
	c.write(0x8, []byte{0x03, 0xE8})
	c.conn.Close()
}
