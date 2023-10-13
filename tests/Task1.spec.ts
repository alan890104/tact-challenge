import { Blockchain, SandboxContract } from '@ton-community/sandbox';
import { toNano } from 'ton-core';
import '@ton-community/test-utils';
import { Task1 } from '../wrappers/Task1';

describe('Task1', () => {
    let blockchain: Blockchain;
    let task1: SandboxContract<Task1>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        task1 = blockchain.openContract(await Task1.fromInit());
        const deployer = await blockchain.treasury('deployer');
        const deployResult = await task1.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );
        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: task1.address,
            deploy: true,
            success: true,
        });
    });

    function getRandomInt(min: number, max: number): number {
        // Make sure min and max are integers
        min = Math.floor(min);
        max = Math.floor(max);

        // Generate a random number between [min, max]
        return Math.floor(Math.random() * (max - min + 1)) + min;
    }

    function getRandomMethod(): 'Add' | 'Subtract' {
        const options = ['Add', 'Subtract'];
        const randomIndex = Math.floor(Math.random() * options.length);
        return options[randomIndex] as 'Add' | 'Subtract';
    }

    it('test', async () => {
        const testCases = 1000;
        for (let i = 0; i < testCases; i++) {
            const randInt = getRandomInt(-1000, 1000);
            const randMethod = getRandomMethod();
            const beforeCounter = await task1.getCounter();
            const deployer = await blockchain.treasury('deployer');
            const result = await task1.send(
                deployer.getSender(),
                {
                    value: toNano('0.05'),
                },
                {
                    $$type: randMethod,
                    queryId: 0n,
                    number: BigInt(randInt),
                }
            );
            expect(result.transactions).toHaveTransaction({
                from: deployer.address,
                to: task1.address,
                success: true,
            });
            expect(await task1.getCounter()).toEqual(beforeCounter + 1n);
        }
    });
});
