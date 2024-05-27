import hashlib
import pdb
import `    `
import json
#pip3 install dill
import dill as serializer
import random
from collections import defaultdict

class Output:
    """ This models a transaction output """
    def __init__(self, constraint = None, amount = 0):
        """ constraint is a function that takes 1 argument which is a list of 
            objects and returns True if the output can be spent.  For example:
            Allow spending without any constraints (the "satisfier" in the Input object can be anything)
            lambda x: True

            Allow spending if the spender can add to 100 (example: satisfier = [40,60]):
            lambda x: x[0] + x[1] == 100

            If the constraint function throws an exception, do not allow spending.
            For example, if the satisfier = ["a","b"] was passed to the previous constraint script

            If the constraint is None, then allow spending without constraint

            amount is the quantity of tokens associated with this output """

        self.constraint = constraint
        self.amount = amount
    
    def getConstraint(self):
        return self.constraint
    
    def getAmount(self):
        return self.amount

class Input:
    """ This models an input (what is being spent) to a blockchain transaction """
    def __init__(self, txHash, txIdx, satisfier):
        """ This input references a prior output by txHash and txIdx.
            txHash is therefore the prior transaction hash
            txIdx identifies which output in that prior transaction is being spent.  It is a 0-based index.
            satisfier is a list of objects that is be passed to the Output constraint script to prove that the output is spendable.
        """
        self.txHash = txHash
        self.txIdx = txIdx
        self.satisfier = satisfier

    def getTxHash(self):    
        return self.txHash

    def getTxIndex(self):
        return self.txIdx
       
class Transaction:
    """ This is a blockchain transaction """
    def __init__(self, inputs=None, outputs=None, data = None):
        """ Initialize a transaction from the provided parameters.
            inputs is a list of Input objects that refer to unspent outputs.
            outputs is a list of Output objects.
            data is a byte array to let the transaction creator put some 
            arbitrary info in their transaction.
        """

        self.inputs = inputs or []
        self.outputs = outputs or []
        self.data = data

    def getHash(self):
        """Return this transaction's probabilistically unique identifier as a big-endian integer"""
        msg = hashlib.sha256();
        serialized_tx = serializer.dumps(self)
        msg.update(serialized_tx)
        
        return int.from_bytes(msg.digest(),"big")

    def getInputs(self):
        """ return a list of all inputs that are being spent """
        return self.inputs

    def getOutputs(self):
        """ Return the output at a particular index """
        return self.outputs

    def getOutput(self, n):
        return self.output[n]

    def validateMint(self, maxCoinsToCreate):
        """ Validate a mint (coin creation) transaction.
            A coin creation transaction should have no inputs,
            and the sum of the coins it creates must be less than maxCoinsToCreate.
        """
        if len(self.inputs) != 0:
          return False 

        outAmount = sum(output.amount for output in self.outputs)
        if maxCoinsToCreate < outAmount:
           return False 
        return True

    def validate(self, unspentOutputDict):
        """ Validate this transaction given a dictionary of unspent transaction outputs.
            unspentOutputDict is a dictionary of items of the following format: { (txHash, offset) : Output }
        """
        ttlIncome, ttlExpenses = 0, 0
        
        for output in self.outputs:
            ttlExpenses += output.amount 

        for i in range(len(self.inputs)):
            input = self.inputs[i]
            txHash = input.txHash
            txIdx = input.txIdx
            if (txHash, txIdx) not in unspentOutputDict: 
                return False 
            unspentOutput = unspentOutputDict[(txHash, txIdx)]
            if input.satisfier==[] or unspentOutput.constraint(input.satisfier):
                ttlIncome += unspentOutput.amount
            else:
                return False

        if(ttlExpenses > ttlIncome and len(self.inputs) != 0):
          return False
        return True
        


class HashableMerkleTree:
    """ A merkle tree of hashable objects.

        If no transaction or leaf exists, use 32 bytes of 0.
        The list of objects that are passed must have a member function named
        .getHash() that returns the object's sha256 hash as an big endian integer.

        Your merkle tree must use sha256 as your hash algorithm and big endian
        conversion to integers so that the tree root is the same for everybody.
        This will make it easy to test.

        If a level has an odd number of elements, append a 0 value element.
        if the merkle tree has no elements, return 0.

    """

    def __init__(self, hashableList = None):
        self.hashables = hashableList or []

    def calcMerkleRoot(self):

        if len(self.hashables)==0:
            return 0
        
        leafNodes = []
        
        for i in range(len(self.hashables)):
            leafNodes.append(self.hashables[i].getHash())
        
        while len(leafNodes) > 1:
            if len(leafNodes)%2!=0:
                leafNodes.append(0)

            newLeaves = []

            for i in range(0, len(leafNodes), 2):
                hxy1 = leafNodes[i].to_bytes(32, "big")
                hxy2 = leafNodes[i+1].to_bytes(32, "big")
                msg = hashlib.sha256()
                msg.update(hxy1)
                msg.update(hxy2)
                newLeaves.append(int.from_bytes(msg.digest(), "big"))
            
            leafNodes = newLeaves

        return leafNodes[0]

class BlockContents:
    """ The contents of the block (merkle tree of transactions)
        This class isn't really needed.  I added it so the project could be cut into
        just the blockchain logic, and the blockchain + transaction logic.
    """
    def __init__(self):
        self.data = HashableMerkleTree()

    def setData(self, d):
        self.data = d

    def getData(self):
        return self.data

    def calcMerkleRoot(self):
        return self.data.calcMerkleRoot()

class Block:
    """ This class should represent a blockchain block.
        It should have the normal fields needed in a block and also an instance of "BlockContents"
        where we will store a merkle tree of transactions.
    """
    def __init__(self):
        # Hint, beyond the normal block header fields what extra data can you keep track of per block to make implementing other APIs easier?
        self.contents = BlockContents()
        self.target = 0 
        self.nonce = 0
        self.priorBlockHash = 0

        self.transaction_list = []
        self.cummulative_work = 0
        self.height = 0

    def getContents(self):
        """Return the Block content (a BlockContents object)"""
        return self.contents

    def setContents(self, data):
        """Set the contents of this block's merkle tree to the list of objects in the data parameter"""
        self.contents.setData(HashableMerkleTree(data))
        self.transaction_list = data

    def setTarget(self, target):
        """Set the difficulty target of this block"""
        self.target = target

    def getTarget(self):
        """Return the difficulty target of this block"""
        return self.target

    def getHash(self):
        """Calculate the hash of this block. Return as an integer"""
        header_data = (
            self.priorBlockHash.to_bytes(32, "big") +
            self.contents.calcMerkleRoot().to_bytes(32, "big") +
            self.target.to_bytes(32, "big") +
            self.nonce.to_bytes(32, "big")
        )
        return int.from_bytes(hashlib.sha256(header_data).digest(), "big")

    def setPriorBlockHash(self, priorHash):
        """Assign the parent block hash"""
        self.priorBlockHash = priorHash

    def getPriorBlockHash(self):
        """Return the parent block hash"""
        return self.priorBlockHash

    def getTransactionList(self):
        return self.transaction_list

    def mine(self, tgt):
        """Update the block header to the passed target (tgt) and then search for a nonce which produces a block whose hash is less than the passed target, "solving" the block"""
        self.target = tgt
        self.nonce = 0
        while True:
            if self.getHash() < self.target:
                break
            self.nonce += 1
        self.target = tgt

    def validate(self, unspentOutputs, maxMint):
        """ Given a dictionary of unspent outputs, and the maximum amount of
            coins that this block can create, determine whether this block is valid.
            Valid blocks satisfy the POW puzzle, have a valid coinbase tx, and have valid transactions (if any exist).

            Return None if the block is invalid.

            Return something else if the block is valid

            661 hint: you may want to return a new unspent output object (UTXO set) with the transactions in this
            block applied, for your own use when implementing other APIs.

            461: you can ignore the unspentOutputs field (just pass {} when calling this function)
        """
        assert type(unspentOutputs) == dict
        valid = 1
        utxo_list = unspentOutputs.copy()

        if(self.getHash() < self.target):
            
            coinbase_count = 0 
            coins_minted = 0 
            for t in self.transaction_list:
                if(not t.validate(unspentOutputs)):
                    return None
                
                if(len(t.getInputs())==0): 
                    coinbase_count +=1
                    for ot in t.getOutputs():
                        coins_minted+=ot.getAmount()
                
            if(coinbase_count > 1) or (coins_minted > maxMint):
                return None 

            for txn  in self.transaction_list:
                for inp in txn.getInputs():
                    txhash, txInd = inp.getTxHash(), inp.getTxIndex()
                    if ((txhash, txInd)  in unspentOutputs):
                        del utxo_list[(txhash, txInd)]
            
            for txn in self.transaction_list:
                output_list = txn.getOutputs()
                for i in range(len(output_list)):
                    txhash, txInd = txn.getHash(), i
                    utxo_list[(txhash, txInd)] = output_list[i]
            return utxo_list
        else:
            return None
class Blockchain(object):

    def __init__(self, genesisTarget, maxMintCoinsPerTx):
        """ Initialize a new blockchain and create a genesis block.
            genesisTarget is the difficulty target of the genesis block (that you should create as part of this initialization).
            maxMintCoinsPerTx is a consensus parameter -- don't let any block into the chain that creates more coins than this!
        """
        self.genesis_block = Block() 
        self.genesis_target = genesisTarget
        self.max_mint_coins = maxMintCoinsPerTx

        self.unspent_outputs_dict = dict()
        
        self.genesis_block.setTarget(genesisTarget)
        self.genesis_block.cummulative_work = self.getWork(self.genesis_target)
        
        self.genesis_block.mine(self.genesis_target)
        self.blocks = defaultdict(Block)

        self.tips_list = []
        self.tips_list.append(self.genesis_block)
        self.blocks[self.genesis_block.getHash()] = self.genesis_block
        self.updateUnspentTransactionsDict(self.genesis_block)

    def getTip(self):
        """ Return the block at the tip (end) of the blockchain fork that has the largest amount of work"""
        tip = self.tips_list[0]
        work_m = self.tips_list[0].cummulative_work
        for t in self.tips_list:
            if(t.cummulative_work > work_m):
                work_m = t.cummulative_work
                tip = t
        return tip       

    def getWork(self, target):
        """Get the "work" needed for this target.  Work is the ratio of the genesis target to the passed target"""
        return self.genesis_target / target
 

    def getCumulativeWork(self, blkHash):
        """Return the cumulative work for the block identified by the passed hash.  Return None if the block is not in the blockchain"""
        return self.blocks[blkHash].cummulative_work

    def getBlocksAtHeight(self, height):
        """Return an array of all blocks in the blockchain at the passed height (including all forks)"""
        ret = []
        for b in self.blocks.values():
            if(b.height == height):
                ret.append(b)
        return ret

    def updateUnspentTransactionsDict(self, block):
        prev_block_hash = block.getPriorBlockHash()

        if(prev_block_hash in self.unspent_outputs_dict.keys()):
            utxo_this_block = self.unspent_outputs_dict[prev_block_hash].copy()
        else:
            utxo_this_block = {}

        for txn in block.getTransactionList():
            for inp in txn.getInputs():
                txhash, txInd = inp.getTxHash(), inp.getTxIndex()

                if ((txhash, txInd)  in utxo_this_block):
                    del utxo_this_block[(txhash, txInd)]
                

        for txn in block.getTransactionList():
            outputs = txn.getOutputs()
            for i in range(len(outputs)):
                txhash, txInd = txn.getHash(), i
                utxo_this_block[(txhash, txInd)] = outputs[i]
        
        self.unspent_outputs_dict[block.getHash()] = utxo_this_block


    def extend(self, block):
        """Adds this block into the blockchain in the proper location, if it is valid.  The "proper location" may not be the tip!

           Hint: Note that this means that you must validate transactions for a block that forks off of any position in the blockchain.
           The easiest way to do this is to remember the UTXO set statef for every block, not just the tip.
           For space efficiency "real" blockchains only retain a single UTXO state (the tip).  This means that during a blockchain reorganization
           they must travel backwards up the fork to the common block, "undoing" all transaction state changes to the UTXO, and then back down
           the new fork.  For this assignment, don't implement this detail, just retain the UTXO state for every block
           so you can easily "hop" between tips.

           Return false if the block is invalid (breaks any miner constraints), and do not add it to the blockchain."""
        prev_block_hash = block.getPriorBlockHash()
        if(prev_block_hash not in self.blocks.keys()):
            return False 
        if(block is None):
            return False
        previous_block = self.blocks[prev_block_hash]
        if(previous_block):
            if(type(block.validate(self.unspent_outputs_dict[prev_block_hash],self.max_mint_coins)) != dict): 
                return False
        else:
            return False

        self.updateUnspentTransactionsDict(block)
        block.mine(block.getTarget())

        self.blocks[block.getHash()] = block
        block.height = previous_block.height+1
        block.cummulative_work = previous_block.cummulative_work + self.getWork(block.getTarget())

        
        if(previous_block in self.tips_list): 
            indx = self.tips_list.index(previous_block)
            self.tips_list[indx] = block
        else:
            self.tips_list.append(block)
        
        return True