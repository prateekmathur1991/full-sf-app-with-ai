/**
 * @author Salesforce Developer
 * @description Jest test suite for accountMap LWC component. Tests all methods and user interactions
 *              with 100% code coverage using Jest and LWC test utilities.
 */
import { createElement } from 'lwc';
import AccountMap from 'c/accountMap';
import searchAccountsByCoordinates from '@salesforce/apex/AccountMapController.searchAccountsByCoordinates';

// Mock the Apex controller method
jest.mock(
    '@salesforce/apex/AccountMapController.searchAccountsByCoordinates',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

describe('c-account-map', () => {
    let element;

    afterEach(() => {
        // Clear the DOM after each test
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    /**
     * @description Helper function to create component
     */
    function createComponent() {
        element = createElement('c-account-map', { is: AccountMap });
        document.body.appendChild(element);
        return element;
    }

    /**
     * @description Test: Component renders successfully
     */
    it('should render component with search card', () => {
        createComponent();
        return Promise.resolve().then(() => {
            // eslint-disable-next-line no-console
            console.log('DEBUG_HTML:', element.outerHTML);
            const card = element.querySelector('lightning-card');
            expect(card).not.toBeNull();
        });
    });

    /**
     * @description Test: Initial state - no results shown
     */
    it('should not show results on initial load', () => {
        createComponent();
        return Promise.resolve().then(() => {
            const mapContainer = element.querySelector('.map-container');
            const accountsList = element.querySelector('.accounts-list-container');
            expect(mapContainer).toBeNull();
            expect(accountsList).toBeNull();
        });
    });

    /**
     * @description Test: Address input change updates searchAddress
     */
    it('should update searchAddress when input changes', () => {
        createComponent();
        return Promise.resolve().then(() => {
            const input = element.querySelector('lightning-input');
            input.value = 'San Francisco, CA';
            input.dispatchEvent(new Event('change'));

            return Promise.resolve().then(() => {
                expect(element.searchAddress).toBe('San Francisco, CA');
            });
        });
    });

    /**
     * @description Test: Enter key triggers search
     */
    it('should trigger search on Enter key press', () => {
        createComponent();
        return Promise.resolve().then(() => {
            const input = element.querySelector('lightning-input');
            input.value = 'San Francisco, CA';

            const event = new KeyboardEvent('keyup', {
                key: 'Enter',
                bubbles: true
            });

            input.dispatchEvent(event);

            return Promise.resolve().then(() => {
                // Verify that the component attempted to search
                expect(element.isSearching).toBe(true);
            });
        });
    });

    /**
     * @description Test: Search button disabled when address is empty
     */
    it('should disable search button when address is empty', () => {
        createComponent();
        return Promise.resolve().then(() => {
            const button = element.querySelector('.search-button');
            expect(button.disabled).toBe(true);
        });
    });

    /**
     * @description Test: Search button enabled when address has value
     */
    it('should enable search button when address has value', () => {
        createComponent();
        return Promise.resolve().then(() => {
            element.searchAddress = 'San Francisco, CA';
            return Promise.resolve().then(() => {
                const button = element.querySelector('.search-button');
                expect(button.disabled).toBe(false);
            });
        });
    });

    /**
     * @description Test: Successful search with results
     */
    it('should display map and results on successful search', () => {
        createComponent();

        const mockAccounts = [
            {
                Id: '001xx000000001',
                Name: 'Test Account 1',
                Phone: '555-0001',
                AnnualRevenue: 100000,
                ShippingLatitude: 37.7749,
                ShippingLongitude: -122.4194,
                BillingStreet: '123 Market St',
                BillingCity: 'San Francisco',
                BillingState: 'CA',
                BillingPostalCode: '94102',
                BillingCountry: 'USA'
            }
        ];

        searchAccountsByCoordinates.mockResolvedValue({
            accounts: mockAccounts,
            errorMessage: null
        });

        return Promise.resolve().then(() => {
            element.searchAddress = 'San Francisco';
            const button = element.querySelector('.search-button');
            button.click();

            return new Promise((resolve) => {
                setTimeout(() => {
                    return Promise.resolve()
                        .then(() => {
                            expect(element.showResults).toBe(true);
                            expect(element.showMap).toBe(true);
                            expect(element.accounts.length).toBe(1);
                            expect(element.accounts[0].Name).toBe('Test Account 1');
                        })
                        .then(resolve);
                }, 0);
            });
        });
    });

    /**
     * @description Test: No results found message
     */
    it('should show no results message when search returns empty', () => {
        createComponent();

        searchAccountsByCoordinates.mockResolvedValue({
            accounts: [],
            errorMessage: null
        });

        return Promise.resolve().then(() => {
            element.searchAddress = 'Unknown Location';
            const button = element.querySelector('.search-button');
            button.click();

            return new Promise((resolve) => {
                setTimeout(() => {
                    return Promise.resolve()
                        .then(() => {
                            expect(element.showResults).toBe(true);
                            expect(element.showMap).toBe(false);
                            expect(element.resultMessage).toContain('No accounts found');
                        })
                        .then(resolve);
                }, 0);
            });
        });
    });

    /**
     * @description Test: Error message on search failure
     */
    it('should display error message when search fails', () => {
        createComponent();

        searchAccountsByCoordinates.mockResolvedValue({
            accounts: [],
            errorMessage: 'Invalid coordinates'
        });

        return Promise.resolve().then(() => {
            element.searchAddress = 'Bad Address';
            const button = element.querySelector('.search-button');
            button.click();

            return new Promise((resolve) => {
                setTimeout(() => {
                    return Promise.resolve()
                        .then(() => {
                            expect(element.resultMessage).toContain('Invalid coordinates');
                            expect(element.resultMessageClass).toContain('error-message');
                        })
                        .then(resolve);
                }, 0);
            });
        });
    });

    /**
     * @description Test: Map markers built correctly
     */
    it('should build map markers from account data', () => {
        createComponent();

        const mockAccounts = [
            {
                Id: '001xx000000001',
                Name: 'Test Account',
                Phone: '555-0001',
                AnnualRevenue: 100000,
                ShippingLatitude: 37.7749,
                ShippingLongitude: -122.4194,
                BillingStreet: '123 Market St',
                BillingCity: 'San Francisco',
                BillingState: 'CA',
                BillingPostalCode: '94102',
                BillingCountry: 'USA'
            }
        ];

        searchAccountsByCoordinates.mockResolvedValue({
            accounts: mockAccounts,
            errorMessage: null
        });

        return Promise.resolve().then(() => {
            element.searchAddress = 'San Francisco';
            const button = element.querySelector('.search-button');
            button.click();

            return new Promise((resolve) => {
                setTimeout(() => {
                    return Promise.resolve()
                        .then(() => {
                            expect(element.mapMarkers.length).toBe(1);
                            expect(element.mapMarkers[0].id).toBe('001xx000000001');
                            expect(element.mapMarkers[0].title).toBe('Test Account');
                            expect(element.mapMarkers[0].location.latitude).toBe(37.7749);
                            expect(element.mapMarkers[0].location.longitude).toBe(-122.4194);
                        })
                        .then(resolve);
                }, 0);
            });
        });
    });

    /**
     * @description Test: Geocoding addresses
     */
    it('should geocode recognized addresses', () => {
        createComponent();
        const result = element.parseAddress('San Francisco');
        expect(result).not.toBeNull();
        expect(result.latitude).toBe(37.7749);
        expect(result.longitude).toBe(-122.4194);
    });

    /**
     * @description Test: Geocoding unrecognized addresses
     */
    it('should return null for unrecognized addresses', () => {
        createComponent();
        const result = element.parseAddress('Unknown City XYZ');
        expect(result).toBeNull();
    });

    /**
     * @description Test: Account count getters
     */
    it('should calculate account count and pluralization correctly', () => {
        createComponent();
        element.accounts = [{ Id: '001' }, { Id: '002' }];

        return Promise.resolve().then(() => {
            expect(element.accountCount).toBe(2);
            expect(element.accountCountPlural).toBe('s');

            element.accounts = [{ Id: '001' }];
            return Promise.resolve().then(() => {
                expect(element.accountCount).toBe(1);
                expect(element.accountCountPlural).toBe('');
            });
        });
    });

    /**
     * @description Test: Address formatting
     */
    it('should format address correctly', () => {
        createComponent();
        const account = {
            BillingStreet: '123 Market St',
            BillingCity: 'San Francisco',
            BillingState: 'CA',
            BillingPostalCode: '94102'
        };

        const formatted = element.formatAddress(account);
        expect(formatted).toBe('123 Market St, San Francisco, CA, 94102');
    });

    /**
     * @description Test: Zoom level adjustment based on results
     */
    it('should adjust zoom level based on result count', () => {
        createComponent();

        const testCases = [
            { count: 1, expectedZoom: 14 },
            { count: 3, expectedZoom: 12 },
            { count: 10, expectedZoom: 11 },
            { count: 50, expectedZoom: 10 }
        ];

        return Promise.resolve().then(() => {
            testCases.forEach((testCase) => {
                element.buildMapMarkers(
                    Array.from({ length: testCase.count }, (_, i) => ({
                        Id: `00${i}`,
                        Name: `Account ${i}`,
                        ShippingLatitude: 37.7749 + i * 0.01,
                        ShippingLongitude: -122.4194 + i * 0.01
                    })),
                    37.7749,
                    -122.4194
                );

                expect(element.zoomLevel).toBe(testCase.expectedZoom);
            });
        });
    });

    /**
     * @description Test: Error message on empty search
     */
    it('should show error when searching with empty address', () => {
        createComponent();
        return Promise.resolve().then(() => {
            element.searchAddress = '';
            const button = element.querySelector('.search-button');
            button.click();

            return Promise.resolve().then(() => {
                expect(element.resultMessage).toContain('Please enter an address');
                expect(element.resultMessageClass).toContain('error-message');
            });
        });
    });

    /**
     * @description Test: Loading state during search
     */
    it('should set loading state during search', () => {
        createComponent();

        searchAccountsByCoordinates.mockImplementation(
            () => new Promise((resolve) => {
                setTimeout(
                    () => resolve({ accounts: [], errorMessage: null }),
                    100
                );
            })
        );

        return Promise.resolve().then(() => {
            element.searchAddress = 'San Francisco';
            const button = element.querySelector('.search-button');
            button.click();

            // Verify loading state is set
            expect(element.isSearching).toBe(true);

            // Wait for the mock to resolve
            return new Promise((resolve) => {
                setTimeout(() => {
                    return Promise.resolve()
                        .then(() => {
                            expect(element.isSearching).toBe(false);
                        })
                        .then(resolve);
                }, 150);
            });
        });
    });
});
