# ZK Treasure Hunt Game Contracts

Smart contracts for a zero-knowledge treasure hunt game, originally developed during ETH Tokyo 2024 Hackathon (https://www.ethtokyo.com/).

The hackathon project details can be found at https://app.akindo.io/hackathons/3dXM7ZO2WsxvlkXp

## Overview

ZK Treasure Hunt is a blockchain-based game where players compete to find a hidden treasure location. The game intends to use zero-knowledge proofs to reveal if player is approaching the treasure while keeping the treasure location private until the game ends.

## Game Mechanics

1. **Registration Phase**
   - Players register by depositing the required registration fee
   - Registration is open until `registrationEndTime`

2. **Active Game Phase**
   - Registered players submit their coordinate guesses
   - Each submission is stored

3. **Resolution Phase**
   - Treasure location is revealed and verified
   - Players evaluate the distance from coordinate to the treasure, updating the latest winner
  
4. **Completed**
   - The closest coordinate is determined based on closest coordinate submission upon the end of resolution phase
   - Prize pool is distributed to the winner
