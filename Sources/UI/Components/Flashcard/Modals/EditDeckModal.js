import React from 'react';
import _ from 'underscore';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Dropdown from 'react-bootstrap/Dropdown';
import DropdownButton from 'react-bootstrap/DropdownButton';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Modal from 'react-bootstrap/Modal';
import Row from 'react-bootstrap/Row';

class EditDeckModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            requestedFI: null,
            scheduleOrder: null,
            newOrder: null,
            reviewOrder: null
        };
    }

    componentDidUpdate(prevProps) {
        if (this.props.deck != prevProps.deck) {
            this.setState({ requestedFI: null, scheduleOrder: null, newOrder: null, reviewOrder: null });
            this.load();
        }
    }

    async load() {
        if (!this.props.deck) return;
        const id = this.props.deck.id;
        const response = await fetch(`/api/flashcard/deck/${id}?includeSM=true`);
        if (response.ok) {
            const deck = await response.json();
            this.setState({ deck });
        }
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const data = Object.fromEntries(new FormData(event.target));
        data.requestedFI = parseInt(data.requestedFI);
        const response = await fetch(`/api/flashcard/deck/${this.state.deck.id}`, {
            method: 'PUT',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        this.setState({
            isSubmitting: false,
            success: response.ok
        });

        if (response.ok) {
            this.props.onSuccess();
            this.setState({
                didError: false,
                message: null
            });
        } else {
            const result = await response.json();
            this.setState({
                didError: result.error,
                message: result.error ? result.reason : null
            });
        }
    }

    requestedFI() {
        return this.state.requestedFI || this.state.deck.requestedFI;
    }

    scheduleOrder() {
        return this.state.scheduleOrder || this.state.deck.scheduleOrder;
    }

    displayForScheduleOrder(o) {
        const dict = {
            'mixNewAndReview': 'Mix New / Review',
            'newAfterReview': 'New After Review',
            'newBeforeReview': 'New Before Review'
        };
        return dict[o];
    }

    newOrder() {
        return this.state.newOrder || this.state.deck.newOrder;
    }

    displayForNewOrder(o) {
        const dict = {
            'random': 'Random',
            'added': 'Added'
        };
        return dict[o];
    }

    reviewOrder() {
        return this.state.reviewOrder || this.state.deck.reviewOrder;
    }

    displayForReviewOrder(o) {
        const dict = {
            'random': 'Random',
            'due': 'Due'
        };
        return dict[o];
    }

    render() {
        return (
            <Modal {...this.props} show={!!this.props.deck} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Edit Deck
                    </Modal.Title>
                </Modal.Header>

                {this.state.deck && <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>
                        <Form.Group controlId="editDeckModalName" className='mb-3'>
                            <Form.Label>Name</Form.Label>
                            <Form.Control defaultValue={this.state.deck.name} autoComplete="off" type="text" name="name" placeholder="Enter the name of the deck" />
                        </Form.Group>
                        <Form.Group controlId="editDeckModalRequestedFI" className='mb-3'>
                            <Form.Label>Forgetting Index</Form.Label>
                            <InputGroup>
                                <Form.Control name='requestedFI' value={this.requestedFI()} readOnly />
                                <Button variant="outline-secondary" onClick={() => this.setState({ requestedFI: Math.max(this.requestedFI() - 1, 3) })}>
                                    -
                                </Button>
                                <Button variant="outline-secondary" onClick={() => this.setState({ requestedFI: Math.min(this.requestedFI() + 1, 20) })}>
                                    +
                                </Button>
                            </InputGroup>
                        </Form.Group>

                        <Form.Group controlId="editDeckScheduleOrder" className='mb-3'>
                            <Form.Label>Schedule Order</Form.Label>
                            <InputGroup className="mt-2 mt-lg-0">
                                <Form.Control value={this.displayForScheduleOrder(this.scheduleOrder())} readOnly />
                                <Form.Control value={this.scheduleOrder()} name='scheduleOrder' hidden />
                                <DropdownButton variant="outline-secondary" title="Order" id="input-group-dropdown-1">
                                    {['mixNewAndReview', 'newAfterReview', 'newBeforeReview'].map((order, i) => {
                                        return <Dropdown.Item key={i} active={this.scheduleOrder() === order} onSelect={() => this.setState({ scheduleOrder: order })}>{this.displayForScheduleOrder(order)}</Dropdown.Item>;
                                    })}
                                </DropdownButton>
                            </InputGroup>
                        </Form.Group>

                        <Form.Group controlId="editDeckNewOrder" className='mb-3'>
                            <Form.Label>New Order <small className='text-muted'>(Only in effect when the schedule order is not mixed)</small></Form.Label>
                            <InputGroup className="mt-2 mt-lg-0">
                                <Form.Control value={this.displayForNewOrder(this.newOrder())} readOnly />
                                <Form.Control value={this.newOrder()} name='newOrder' hidden />
                                <DropdownButton variant="outline-secondary" title="Order" id="input-group-dropdown-1">
                                    {['random', 'added'].map((order, i) => {
                                        return <Dropdown.Item key={i} active={this.newOrder() === order} onSelect={() => this.setState({ newOrder: order })}>{this.displayForNewOrder(order)}</Dropdown.Item>;
                                    })}
                                </DropdownButton>
                            </InputGroup>
                        </Form.Group>

                        <Form.Group controlId="editDeckReviewOrder" className='mb-3'>
                            <Form.Label>Review Order <small className='text-muted'>(Only in effect when the schedule order is not mixed)</small></Form.Label>
                            <InputGroup className="mt-2 mt-lg-0">
                                <Form.Control value={this.displayForReviewOrder(this.reviewOrder())} readOnly />
                                <Form.Control value={this.reviewOrder()} name='reviewOrder' hidden />
                                <DropdownButton variant="outline-secondary" title="Order" id="input-group-dropdown-1">
                                    {['random', 'due'].map((order, i) => {
                                        return <Dropdown.Item key={i} active={this.reviewOrder() === order} onSelect={() => this.setState({ reviewOrder: order })}>{this.displayForReviewOrder(order)}</Dropdown.Item>;
                                    })}
                                </DropdownButton>
                            </InputGroup>
                        </Form.Group>

                        {this.state.didError && <Alert variant="danger" className='mb-3'>
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert variant="info" className='mb-3'>
                            {this.state.message}
                        </Alert>}

                        <Button className='col-12' variant="primary" type="submit" disabled={this.state.isSubmitting}>
                            {this.state.isSubmitting ? 'Saving...' : 'Save'}
                        </Button>
                    </Form>
                </Modal.Body>}
            </Modal>
        );
    }
}

export default EditDeckModal;
