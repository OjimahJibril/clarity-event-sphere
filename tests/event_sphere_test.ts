import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure contract pause functionality works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('event_sphere', 'toggle-contract-pause', [], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Attempt to stake while paused
    let stakeBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'stake-stx', [
        types.uint(50000000)
      ], wallet1.address)
    ]);
    
    stakeBlock.receipts[0].result.expectErr(106); // err-contract-paused
  }
});

Clarinet.test({
  name: "Test stake withdrawal with timelock",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    // Stake STX
    let stakeBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'stake-stx', [
        types.uint(50000000)
      ], wallet1.address)
    ]);
    
    stakeBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Attempt immediate withdrawal
    let withdrawBlock = chain.mineBlock([
      Tx.contractCall('event_sphere', 'withdraw-stake', [
        types.uint(25000000)
      ], wallet1.address)
    ]);
    
    withdrawBlock.receipts[0].result.expectErr(107); // err-timelock-active
    
    // Advance chain past timelock
    chain.mineEmptyBlockUntil(145);
    
    // Try withdrawal again
    let successfulWithdraw = chain.mineBlock([
      Tx.contractCall('event_sphere', 'withdraw-stake', [
        types.uint(25000000)
      ], wallet1.address)
    ]);
    
    successfulWithdraw.receipts[0].result.expectOk().expectBool(true);
  }
});

// [Previous tests remain unchanged]
