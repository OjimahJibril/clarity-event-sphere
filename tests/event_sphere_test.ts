import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure can create event",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('event_sphere', 'create-event', [
        types.ascii("Test Event"),
        types.utf8("Test Description"),
        types.uint(1000),
        types.uint(100),
        types.uint(10000000)
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk().expectUint(0);
    
    // Verify event details
    let eventBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'get-event', [
        types.uint(0)
      ], deployer.address)
    ]);
    
    const event = eventBlock.receipts[0].result.expectSome().expectTuple();
    assertEquals(event['name'], "Test Event");
    assertEquals(event['max-tickets'], types.uint(100));
  }
});

Clarinet.test({
  name: "Ensure can buy ticket",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // First create event
    let setupBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'create-event', [
        types.ascii("Test Event"),
        types.utf8("Test Description"),
        types.uint(1000),
        types.uint(100),
        types.uint(10000000)
      ], deployer.address)
    ]);
    
    // Buy ticket
    let block = chain.mineBlock([
      Tx.contractCall('event_sphere', 'buy-ticket', [
        types.uint(0)
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectOk().expectUint(0);
    
    // Verify ticket ownership
    let ticketBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'get-ticket', [
        types.uint(0)
      ], wallet1.address)
    ]);
    
    const ticket = ticketBlock.receipts[0].result.expectSome().expectTuple();
    assertEquals(ticket['owner'], wallet1.address);
    assertEquals(ticket['status'], "valid");
  }
});

Clarinet.test({
  name: "Ensure can create and vote on proposal",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Create event
    let setupBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'create-event', [
        types.ascii("Test Event"),
        types.utf8("Test Description"),
        types.uint(1000),
        types.uint(100),
        types.uint(10000000)
      ], deployer.address)
    ]);
    
    // Create proposal
    let proposalBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'create-proposal', [
        types.ascii("Test Proposal"),
        types.utf8("Proposal Description"),
        types.uint(0),
        types.uint(1000)
      ], deployer.address)
    ]);
    
    proposalBlock.receipts[0].result.expectOk().expectUint(0);
    
    // Vote on proposal
    let voteBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'vote-on-proposal', [
        types.uint(0),
        types.bool(true)
      ], wallet1.address)
    ]);
    
    voteBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Verify proposal status
    let statusBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'get-proposal', [
        types.uint(0)
      ], deployer.address)
    ]);
    
    const proposal = statusBlock.receipts[0].result.expectSome().expectTuple();
    assertEquals(proposal['yes-votes'], types.uint(1));
  }
});