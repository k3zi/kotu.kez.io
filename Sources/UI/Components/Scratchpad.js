import _ from 'underscore';
import { withRouter } from 'react-router';
import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';
import Tabs from 'react-bootstrap/Tabs';
import Tab from 'react-bootstrap/Tab';

import Helpers from './Helpers';
import ContentEditable from './Common/ContentEditable';

class Scratchpad extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            content: ''
        };
        const self = this;
        this.onChange = _.throttle(() => { self.onChange(); }, 250);
    }

    onTextChange(e) {
        this.setState({ content: e.target.value });
    }

    render() {
        return (<div>
            <Row>
                <Col>
                    <ContentEditable value={this.state.content} onChange={(e) => this.onTextChange(e)} className='form-control h-auto text-break plaintext clickable' />
                </Col>
                <Col>
                    <div dangerouslySetInnerHTML={{__html: Helpers.parseMarkdown(this.state.content)}}></div>
                </Col>
            </Row>
            <h6 className='text-muted mt-2'>Type in the left box and the preview will appear to the right.</h6>
        </div>);
    }
}

export default withRouter(Scratchpad);
