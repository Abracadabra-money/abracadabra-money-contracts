function getMaxProportionalAmounts(amounts: number[], proportions: number[]): number[] {
    // Determine the maximum total amount by finding the smallest relationship value
    const totalAmounts = amounts.map((amount, index) => amount / proportions[index]);
    const maxTotal = Math.min(...totalAmounts);

    // Calculate the adjusted amounts based on the total
    return proportions.map(prop => maxTotal * prop);
}

console.log(getMaxProportionalAmounts([50, 322, 500], [0.27, 0.29, 0.44]));