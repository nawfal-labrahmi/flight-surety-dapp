class OracleMock {
    constructor(address) {
        this.address = address;
        this.indexes = [];
    }

    setIndexes(indexes) {
        this.indexes = indexes.map(index => index.toNumber());
    }

    hasIndex(index) {
        return this.indexes.some(i => i === index);
    }
}

module.exports = OracleMock;
