/**
 * @author Salesforce Developer
 * @description Lightning Web Component for displaying Salesforce accounts on an interactive map.
 *              Users can search for accounts by entering an address, and the component displays all
 *              accounts within 50 miles of that address on a map with detailed information on hover.
 */
import { api, LightningElement } from 'lwc';
import searchAccountsByCoordinates from '@salesforce/apex/AccountMapController.searchAccountsByCoordinates';

export default class AccountMap extends LightningElement {

    @api title = 'Account Map';
    @api searchAddress = '';
    @api isSearching = false;
    @api accounts = [];
    @api mapMarkers = [];
    @api zoomLevel = 12;
    @api resultMessage = '';
    @api resultMessageClass = '';
    @api showMap = false;
    @api showResults = false;
    lastSearchLatitude = null;
    lastSearchLongitude = null;
    
    handleAddressChange(event) {
        this.searchAddress = event.target.value;
    }

    isSearchButtonDisabled() {
        return !this.searchAddress || this.searchAddress.trim().length === 0 || this.isSearching;
    }

    get searchButtonLabel() {
        return this.isSearching ? 'Searching...' : 'Search';
    }

    handleSearchKeyup(event) {
        if (event.key === 'Enter' && this.searchAddress) {
            this.handleSearch();
        }
    }

    handleSearch() {
        if (!this.searchAddress || this.searchAddress.trim().length === 0) {
            this.setErrorMessage('Please enter an address to search');
            return;
        }

        this.isSearching = true;
        this.resultMessage = 'Searching...';
        this.resultMessageClass = 'info-message';

        this.geocodeAddress(this.searchAddress);
    }

    geocodeAddress(address) {
        // For demo purposes: Parse known addresses or use default coordinates
        // In production, integrate with Google Maps Geocoding API or Salesforce Location Services
        const coordinates = this.parseAddress(address);

        if (coordinates) {
            this.searchByCoordinates(coordinates.latitude, coordinates.longitude);
        } else {
            this.setErrorMessage('Could not geocode address. Please try another address.');
            this.isSearching = false;
        }
    }

    @api
    parseAddress(address) {
        const lowerAddress = address.toLowerCase();

        // Demo address mappings
        const addressMap = {
            'san francisco': { latitude: 37.7749, longitude: -122.4194 },
            'new york': { latitude: 40.7128, longitude: -74.006 },
            'los angeles': { latitude: 34.0522, longitude: -118.2437 },
            'chicago': { latitude: 41.8781, longitude: -87.6298 },
            'seattle': { latitude: 47.6062, longitude: -122.3321 },
            'boston': { latitude: 42.3601, longitude: -71.0589 },
            'denver': { latitude: 39.7392, longitude: -104.9903 },
            'miami': { latitude: 25.7617, longitude: -80.1918 },
            'portland': { latitude: 45.5152, longitude: -122.6784 },
            'austin': { latitude: 30.2672, longitude: -97.7431 }
        };

        for (const [key, coords] of Object.entries(addressMap)) {
            if (lowerAddress.includes(key)) {
                return coords;
            }
        }

        return null;
    }

    searchByCoordinates(latitude, longitude) {
        this.lastSearchLatitude = latitude;
        this.lastSearchLongitude = longitude;

        searchAccountsByCoordinates({
            latitude: latitude,
            longitude: longitude,
            distanceMiles: 50
        })
            .then((result) => {
                this.handleSearchResult(result, latitude, longitude);
            })
            .catch((error) => {
                this.setErrorMessage('Error searching accounts: ' + error.body.message);
                this.isSearching = false;
            });
    }

    handleSearchResult(result, latitude, longitude) {
        if (result.errorMessage) {
            this.setErrorMessage(result.errorMessage);
        } else if (result.accounts && result.accounts.length > 0) {
            this.accounts = result.accounts;
            this.buildMapMarkers(result.accounts, latitude, longitude);
            this.showResults = true;
            this.showMap = true;
            this.resultMessage = `Successfully found ${result.accounts.length} account(s) within 50 miles`;
            this.resultMessageClass = 'success-message';
        } else {
            this.accounts = [];
            this.showResults = true;
            this.showMap = false;
            this.resultMessage = 'No accounts found within 50 miles of that location';
            this.resultMessageClass = 'info-message';
        }

        this.isSearching = false;
    }

    @api
    buildMapMarkers(accountList, centerLatitude, centerLongitude) {
        this.mapMarkers = accountList.map((account) => ({
            id: account.Id,
            title: account.Name,
            description: this.buildMarkerDescription(account),
            location: {
                latitude: account.ShippingLatitude,
                longitude: account.ShippingLongitude
            }
        }));

        // Set zoom level based on result count
        if (accountList.length === 1) {
            this.zoomLevel = 14;
        } else if (accountList.length <= 5) {
            this.zoomLevel = 12;
        } else if (accountList.length <= 20) {
            this.zoomLevel = 11;
        } else {
            this.zoomLevel = 10;
        }
    }

    buildMarkerDescription(account) {
        const revenue = account.AnnualRevenue ? '$' + account.AnnualRevenue.toLocaleString() : 'N/A';
        const address = this.formatAddress(account);

        return `Name: ${account.Name}\nPhone: ${account.Phone || 'N/A'}\nRevenue: ${revenue}\nAddress: ${address}`;
    }

    @api
    formatAddress(account) {
        const parts = [];
        if (account.BillingStreet) parts.push(account.BillingStreet);
        if (account.BillingCity) parts.push(account.BillingCity);
        if (account.BillingState) parts.push(account.BillingState);
        if (account.BillingPostalCode) parts.push(account.BillingPostalCode);

        return parts.length > 0 ? parts.join(', ') : 'N/A';
    }

    setErrorMessage(message) {
        this.resultMessage = message;
        this.resultMessageClass = 'error-message';
        this.showResults = false;
        this.showMap = false;
    }

    @api
    get accountCount() {
        return this.accounts ? this.accounts.length : 0;
    }

    @api
    get accountCountPlural() {
        return this.accountCount === 1 ? '' : 's';
    }
}
