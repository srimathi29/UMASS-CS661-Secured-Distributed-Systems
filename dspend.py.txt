import random
import math
import sys

# Wouldnt it be nice for graders to see your explaination of what craziness you are doing???
def satoshi(q,z):
    return 0.0
'''
import math

def satoshi(q, z):
    p = 1 - q
    lambd = z * q / p
    probabilityOfAttackerSuccess = 1 - sum(((lambd ** k) * math.exp(-lambd)) / math.factorial(k) * (1 - (q / p) ** (z - k)) for k in range(z + 1))
    return probabilityOfAttackerSuccess
'''
# Remember to comment the what, why and high-level how
# Dont explain basic python language features.  Expect that your reader knows python.  Explain what you are trying to do and how the python code
# gets there!
'''
import random

def simulate_double_spend(q, z):
    p = 1 - q
    numAttackerSuccess = 0

    for _ in range(50000):
        attacker_blocks = 0
        honest_blocks = 0

        while True:
            if random.random() <= q:
                attacker_blocks += 1
            else:
                honest_blocks += 1

            if honest_blocks >= z and honest_blocks - attacker_blocks >= 35:
                break

        if attacker_blocks > honest_blocks:
            numAttackerSuccess += 1

    return numAttackerSuccess / 50000

def monte(q, z, numTrials=50000):
    return simulate_double_spend(q, z)

# Example usage:
# result = monte(0.3, 6)
# print(result)
'''
MAX_LEAD = 35
def monteCarlo(q,z, numTrials=50000):
    return 0.0

def markovChainSum(q,z):
    return 0.0
'''
def markov(q, z):
    p = 1 - q
    cache = {}

    def recursive_probability(attacker_lead):
        if attacker_lead >= z + 35:
            return 1.0
        elif attacker_lead <= -z - 35:
            return 0.0

        if attacker_lead in cache:
            return cache[attacker_lead]

        prob_attacker_find_block = q * recursive_probability(attacker_lead + 1)
        prob_honest_find_block = (1 - q) * recursive_probability(attacker_lead - 1)

        final_probability = prob_attacker_find_block + prob_honest_find_block
        cache[attacker_lead] = final_probability

        return final_probability

    return recursive_probability(0)

# Example usage:
# result = markov(0.3, 6)
# print(result)
'''
# Testing your work by repeated submission is a giant waste of your time.  Always optimize your time when coding!!!
# Instead, write your own tests!
def Test():
  # Your algorithm might go deep, so you may need to change the recursion limit.
  # At the same time, this might make an infinite recursion hard to find
  sys.setrecursionlimit(5000)
  q=0.3

  for z in range(0,11):
    s = satoshi(q,z)
    mc = monteCarlo(q,z, 10000)
    ms = markovChainSum(q,z)
    print("q:", q, " z:", z, " satoshi: %3.3f" % (s*100), " monte carlo: %3.3f" % (mc*100), " markov sum: %3.3f" % (ms*100))
