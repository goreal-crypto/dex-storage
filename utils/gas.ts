import {Address, Cell} from "@ton/core"
import type {Blockchain, SendMessageResult} from "@ton/sandbox"
import chalk from "chalk"

type GasConsumptionChain = {
    type: "chain"
    chainLength?: number // undefined means all transactions in the chain
}

type GasConsumptionSingle = {
    type: "single"
}

type GasConsumption = GasConsumptionChain | GasConsumptionSingle

export function getUsedGasInternal(
    sendResult: SendMessageResult,
    consumptionType: GasConsumption,
): number {
    const lastTxInChainNumber =
        consumptionType.type === "chain"
            ? typeof consumptionType.chainLength === "undefined"
                ? undefined
                : consumptionType.chainLength + 1
            : 2

    return sendResult.transactions
        .slice(1, lastTxInChainNumber)
        .map(t =>
            t.description.type === "generic" && t.description.computePhase.type === "vm"
                ? Number(t.description.computePhase.gasUsed)
                : 0,
        )
        .reduceRight((prev, cur) => prev + cur)
}

type BenchmarkResult = {
    label: string
    pr: string | undefined
    gas: Record<string, number>
    summary: number
}

export type RawBenchmarkResult = {
    results: {
        label: string
        pr: string | null
        gas: Record<string, string | undefined>
        summary: string
    }[]
}

export function generateResults(benchmarkResults: RawBenchmarkResult): BenchmarkResult[] {
    return benchmarkResults.results.map(result => ({
        label: result.label,
        pr: result.pr ?? undefined,
        gas: Object.fromEntries(
            Object.entries(result.gas).map(([key, value]) => [key, Number(value)]),
        ),
        summary: Number(result.summary),
    }))
}

export type RawCodeSizeResult = {
    results: {
        label: string
        pr: string | null
        size: Record<string, string>
    }[]
}

type CodeSizeResult = {
    label: string
    pr: string | undefined
    size: Record<string, number>
}

export function generateCodeSizeResults(benchmarkResults: RawCodeSizeResult): CodeSizeResult[] {
    return benchmarkResults.results.map(result => ({
        label: result.label,
        pr: result.pr ?? undefined,
        size: Object.fromEntries(
            Object.entries(result.size).map(([key, value]) => [key, Number(value)]),
        ),
    }))
}

const calculateCellsAndBits = (root: Cell, visited: Set<string> = new Set<string>()) => {
    const hash = root.hash().toString("hex")
    if (visited.has(hash)) {
        return {cells: 0, bits: 0}
    }
    visited.add(hash)

    let cells = 1
    let bits = root.bits.length
    for (const ref of root.refs) {
        const childRes = calculateCellsAndBits(ref, visited)
        cells += childRes.cells
        bits += childRes.bits
    }
    return {cells, bits}
}

export async function getStateSizeForAccount(
    blockchain: Blockchain,
    address: Address,
): Promise<{cells: number; bits: number}> {
    const accountState = (await blockchain.getContract(address)).accountState
    if (!accountState || accountState.type !== "active") {
        throw new Error("Account state not found")
    }
    if (!accountState.state.code || !accountState.state.data) {
        throw new Error("Account state code or data not found")
    }
    const accountCode = accountState.state.code
    const accountData = accountState.state.data

    const codeSize = calculateCellsAndBits(accountCode)
    const dataSize = calculateCellsAndBits(accountData)

    return {
        cells: codeSize.cells + dataSize.cells,
        bits: codeSize.bits + dataSize.bits,
    }
}

