import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import YouTube from 'react-youtube';

class SearchResultModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isLoading: true,
            isFocused: false,
            inList: false,
            selectedResult: null,
            selectedResultHTML: '',
            isSubmitting: false
        };
    }

    componentDidUpdate(prevProps, prevState) {
        if (prevProps.headword !== this.props.headword) {
            this.loadResult();
        }
    }

    async loadResult() {
        this.setState({ isLoading: true });
        const response = await fetch(`/api/dictionary/entry/${this.props.headword.id}`);
        const result = await response.text();
        this.setState({ selectedResultHTML: result, isLoading: false });

        this.checkList();
    }

    async checkList() {
        const response = await fetch(`/api/lists/word/first?q=${encodeURIComponent(this.props.headword.headline)}&isLookup=1`);
        this.setState({ inList: response.ok });
    }

    async addToList() {
        this.setState({ isSubmitting: true });

        const data = {
            value: this.props.headword.headline
        };
        const response = await fetch(`/api/lists/word`, {
            method: 'POST',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        const result = await response.json();
        const success = !result.error;

        this.setState({
            isSubmitting: false,
            inList: response.ok
        });
    }

    render() {
        return (
            <Modal {...this.props} size="lg" centered>
                <Modal.Header closeButton>
                    <Modal.Title>{this.props.headword && this.props.headword.headline}</Modal.Title>
                    <Button onClick={() => this.addToList()} className='ms-2' variant='primary' disabled={this.state.inList}>{this.state.inList ? 'Added' : 'Add to List'}</Button>
                </Modal.Header>
                <Modal.Body>
                    {this.state.isLoading && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}
                    {!this.state.isLoading && <iframe className="col-12" style={{ height: '60vh' }} srcDoc={this.state.selectedResultHTML} frameBorder="0"></iframe>}
                </Modal.Body>
            </Modal>
        );
    }
}

export default SearchResultModal;
