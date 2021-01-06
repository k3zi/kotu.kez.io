import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';

class EditFragmentModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false
        };
    }

    parseMilliseconds(time) {
        let milliseconds = 0;
        const s = time.split('.');
        if (s.length > 1) {
            milliseconds += parseInt(s[s.length - 1]);
        }
        const f = s[0];
        const a = f.split(':');
        const multipliers = [1000, 60 * 1000, 60 * 60 * 1000];
        let i = 0;
        while (a.length > 0 && i < 3) {
            milliseconds += parseInt(a.pop() * multipliers[i]);
            i += 1;
        }
        return milliseconds;
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const data = Object.fromEntries(new FormData(event.target));
        data.startTime = this.parseMilliseconds(data.startTime) / 1000;
        data.endTime = this.parseMilliseconds(data.endTime) / 1000;
        const response = await fetch(`/api/transcription/project/${this.props.project.id}/fragment/${this.props.fragment.id}`, {
            method: 'PUT',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        const result = await response.json();
        const success = !result.error;
        this.setState({
            isSubmitting: false,
            success
        });

        if (response.ok) {
            this.props.onFinish(result);
        } else {
            this.setState({
                didError: result.error,
                message: result.reason
            });
        }
    }

    render() {
        return (
            <Modal {...this.props} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Update Fragment
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>
                        <Form.Group controlId="editFragmentModalStartTime">
                            <Form.Label>Start Time (format: hh:mm:ss:zzz)</Form.Label>
                            <Form.Control autoComplete='off' name="startTime" placeholder="Enter start time (ex: 0:02)" />
                        </Form.Group>
                        <Form.Group controlId="editFragmentModalEndTime" className='mt-3'>
                            <Form.Label>End Time (format: hh:mm:ss:zzz)</Form.Label>
                            <Form.Control autoComplete='off' name="endTime" placeholder="Enter end time (ex: 0:25)" />
                        </Form.Group>

                        {this.state.didError && <Alert variant="danger" className='mt-3'>
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert variant="info" className='mt-3'>
                            {this.state.message}
                        </Alert>}

                        {<Button variant="secondary" className='mt-3' disabled={this.state.isSubmitting} onClick={() => this.props.didCancel()}>Cancel</Button>}
                        {' '}
                        {<Button variant="primary" className='mt-3' type="submit" disabled={this.state.isSubmitting}>
                            {this.state.isSubmitting ? 'Saving...' : 'Save'}
                        </Button>}
                    </Form>
                </Modal.Body>
            </Modal>
        );
    }
}

export default EditFragmentModal;
