import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// [Previous test cases remain unchanged]

Clarinet.test({
  name: "Ensure revenue sharing system works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // Create event with revenue sharing
    let setupBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'create-event', [
        types.ascii("Test Event"),
        types.utf8("Test Description"),
        types.uint(1000),
        types.uint(100),
        types.uint(10000000),
        types.uint(70), // organizer share
        types.uint(20), // dao share
        types.uint(10)  // stakeholder share
      ], deployer.address)
    ]);
    
    // Stake STX
    let stakeBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'stake-stx', [
        types.uint(50000000)
      ], wallet1.address)
    ]);
    
    // Buy tickets
    let buyBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'buy-ticket', [
        types.uint(0)
      ], wallet2.address)
    ]);
    
    // Advance chain
    chain.mineEmptyBlockUntil(1001);
    
    // Claim revenue
    let claimBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'claim-revenue-share', [
        types.uint(0)
      ], wallet1.address)
    ]);
    
    claimBlock.receipts[0].result.expectOk().expectBool(true);
  }
});
