import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Test event completion and revenue distribution",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const organizer = accounts.get('wallet_1')!;
    
    // Create event
    let createBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'create-event', [
        types.ascii("Test Event"),
        types.utf8("Description"),
        types.uint(100),  // date
        types.uint(100),  // max tickets
        types.uint(10000000),  // price
        types.tuple({
          organizer-share: types.uint(70),
          dao-share: types.uint(20),
          stakeholder-share: types.uint(10)
        })
      ], organizer.address)
    ]);
    
    createBlock.receipts[0].result.expectOk();
    
    // Complete event
    chain.mineEmptyBlockUntil(101);
    
    let completeBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'complete-event', [
        types.uint(0)
      ], organizer.address)
    ]);
    
    completeBlock.receipts[0].result.expectOk();
    
    // Distribute revenue
    let distributeBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'distribute-event-revenue', [
        types.uint(0)
      ], organizer.address)
    ]);
    
    distributeBlock.receipts[0].result.expectOk();
  }
});

// [Previous tests remain unchanged]
