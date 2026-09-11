const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
	...jestConfig,
	modulePathIgnorePatterns: ['<rootDir>/.localdevserver'],
	moduleNameMapper: {
		'^lightning/flowSupport$': '<rootDir>/force-app/test/jest-mocks/lightning/flowSupport'
	}
};
